#!/usr/bin/env zsh
# Tahoe Memory Hog Reaper
# Safe macOS memory hog diagnostic CLI. Diagnostic-first; no sudo; no auto-kill.

set -u

SCRIPT_NAME="${0:t}"
VERSION="0.1.0"
DEFAULT_THRESHOLD_GB=20
TOP_N=12
DENYLIST=(kernel_task launchd WindowServer loginwindow syslogd notifyd opendirectoryd)

usage() {
  cat <<'EOF'
Tahoe Memory Hog Reaper

Usage:
  ./tahoe-memory-hog-reaper.zsh status
  ./tahoe-memory-hog-reaper.zsh scan [--threshold-gb N]
  ./tahoe-memory-hog-reaper.zsh reap --interactive [--threshold-gb N] [--confirm]
  ./tahoe-memory-hog-reaper.zsh help
  ./tahoe-memory-hog-reaper.zsh --version

Safety:
  - Diagnostic by default.
  - No sudo, no daemon, no automatic killing.
  - reap is dry-run unless --confirm is passed and you type the target PID.
EOF
}

has_cmd() { command -v "$1" >/dev/null 2>&1 }

rss_kb_to_gb() {
  awk -v kb="$1" 'BEGIN { printf "%.2f", kb / 1024 / 1024 }'
}

short_cmd() {
  awk -v s="$1" 'BEGIN { if (length(s) > 96) print substr(s, 1, 93) "..."; else print s }'
}

print_memory_pressure() {
  echo "Memory pressure:"
  if has_cmd memory_pressure; then
    memory_pressure 2>/dev/null | head -n 8 | sed 's/^/  /'
  else
    echo "  memory_pressure command not found on this system."
  fi
}

print_vm_summary() {
  echo "VM / swap summary:"
  if has_cmd sysctl; then
    sysctl vm.swapusage 2>/dev/null | sed 's/^/  /' || echo "  swapusage unavailable"
  else
    echo "  sysctl not found."
  fi
  if has_cmd vm_stat; then
    vm_stat 2>/dev/null | head -n 8 | sed 's/^/  /'
  else
    echo "  vm_stat not found."
  fi
}

process_rows() {
  ps -axo pid=,rss=,pcpu=,command= 2>/dev/null | awk '
    NF >= 4 && $1 ~ /^[0-9]+$/ && $2 ~ /^[0-9]+$/ {
      pid=$1; rss=$2; cpu=$3; cmd="";
      for (i=4; i<=NF; i++) cmd = cmd (i==4 ? "" : " ") $i;
      printf "%s\t%s\t%s\t%s\n", pid, cmd, rss, cpu;
    }' | sort -t $'\t' -k3,3nr
}

print_top_processes() {
  echo "Top memory processes:"
  printf "  %-7s %-7s %-6s %s\n" "PID" "RSS_GB" "CPU%" "COMMAND"
  process_rows | head -n "$TOP_N" | while IFS=$'\t' read -r pid name rss cpu; do
    printf "  %-7s %-7s %-6s %s\n" "$pid" "$(rss_kb_to_gb "$rss")" "$cpu" "$(short_cmd "$name")"
  done
}

threshold_kb() {
  awk -v gb="$1" 'BEGIN { printf "%.0f", gb * 1024 * 1024 }'
}

is_protected() {
  local name="$1"
  local exe="${name%% *}"
  local base="${exe:t}"
  for protected in "${DENYLIST[@]}"; do
    [[ "$base" == "$protected" || "$exe" == "$protected" || "$name" == *"/$protected"* ]] && return 0
  done
  return 1
}

scan_hogs() {
  local threshold_gb="$1"
  local limit_kb="$(threshold_kb "$threshold_gb")"
  echo "Candidates above ${threshold_gb}GB RSS:"
  printf "  %-7s %-7s %-10s %s\n" "PID" "RSS_GB" "PROTECTED" "COMMAND"
  local found=0
  process_rows | while IFS=$'\t' read -r pid name rss cpu; do
    if (( rss >= limit_kb )); then
      local protected="no"
      is_protected "$name" && protected="yes"
      printf "  %-7s %-7s %-10s %s\n" "$pid" "$(rss_kb_to_gb "$rss")" "$protected" "$(short_cmd "$name")"
      found=1
    fi
  done
  if [[ "$found" == "0" ]]; then
    echo "  No process above threshold. Try a lower --threshold-gb value."
  fi
}

parse_threshold() {
  local threshold="$DEFAULT_THRESHOLD_GB"
  while (( $# > 0 )); do
    case "$1" in
      --threshold-gb)
        shift
        [[ $# -gt 0 ]] || { echo "Missing value for --threshold-gb" >&2; return 2; }
        threshold="$1"
        ;;
    esac
    shift || true
  done
  echo "$threshold"
}

cmd_status() {
  print_memory_pressure
  echo
  print_vm_summary
  echo
  print_top_processes
}

cmd_scan() {
  local threshold="$(parse_threshold "$@")" || return $?
  scan_hogs "$threshold"
}

cmd_reap() {
  local threshold="$(parse_threshold "$@")" || return $?
  local interactive=0 confirm=0
  for arg in "$@"; do
    [[ "$arg" == "--interactive" ]] && interactive=1
    [[ "$arg" == "--confirm" ]] && confirm=1
  done
  (( interactive == 1 )) || { echo "Refusing: reap requires --interactive." >&2; return 2; }

  scan_hogs "$threshold"
  echo
  echo "Dry-run safety: no signal will be sent unless --confirm is passed and you type the PID exactly."
  (( confirm == 1 )) || return 0

  printf "PID to TERM (or blank to cancel): "
  read -r target_pid
  [[ -n "$target_pid" && "$target_pid" == <-> ]] || { echo "Cancelled."; return 0; }

  local row="$(process_rows | awk -F '\t' -v pid="$target_pid" '$1 == pid { print; exit }')"
  [[ -n "$row" ]] || { echo "PID not found." >&2; return 1; }
  local name="${row#*$'\t'}"; name="${name%%$'\t'*}"
  if is_protected "$name"; then
    echo "Refusing to signal protected process: $name" >&2
    return 1
  fi

  printf "Type %s again to send TERM to %s: " "$target_pid" "$name"
  read -r typed
  [[ "$typed" == "$target_pid" ]] || { echo "Cancelled."; return 0; }
  kill -TERM "$target_pid"
  echo "TERM sent to PID $target_pid ($name)."
}

main() {
  local cmd="${1:-help}"
  shift || true
  case "$cmd" in
    status) cmd_status "$@" ;;
    scan) cmd_scan "$@" ;;
    reap) cmd_reap "$@" ;;
    help|-h|--help) usage ;;
    version|-v|--version) echo "Tahoe Memory Hog Reaper ${VERSION}" ;;
    *) echo "Unknown command: $cmd" >&2; usage; return 2 ;;
  esac
}

main "$@"
