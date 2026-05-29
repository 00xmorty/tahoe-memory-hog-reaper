# Tahoe Memory Hog Reaper

A tiny macOS CLI for spotting runaway memory hogs before your Mac hits “out of application memory”.

## Why

Some macOS apps can suddenly consume tens of GB of RAM while sitting in the background. Activity Monitor works, but in the middle of a slowdown you want one clear terminal command that says what is happening and which process is the likely culprit.

Tahoe Memory Hog Reaper is intentionally small and safe: it reports first, uses normal macOS command-line tools, does not require sudo, and never kills anything automatically.

## Requirements

- macOS
- `zsh`
- Standard macOS tools: `ps`, `awk`, `sort`, `head`, `sysctl`, `vm_stat`
- Optional: `memory_pressure` when available on your macOS version

## Install

Clone the repo and run the script directly:

```sh
git clone https://github.com/00xmorty/tahoe-memory-hog-reaper.git
cd tahoe-memory-hog-reaper
chmod +x tahoe-memory-hog-reaper.zsh
./tahoe-memory-hog-reaper.zsh status
```

Or copy the script somewhere on your `PATH`:

```sh
cp tahoe-memory-hog-reaper.zsh /usr/local/bin/tahoe-memory-hog-reaper
chmod +x /usr/local/bin/tahoe-memory-hog-reaper
tahoe-memory-hog-reaper status
```

## Commands

```sh
./tahoe-memory-hog-reaper.zsh status
./tahoe-memory-hog-reaper.zsh scan --threshold-gb 20
./tahoe-memory-hog-reaper.zsh reap --interactive --threshold-gb 40
./tahoe-memory-hog-reaper.zsh --version
```

### `status`

Prints:

- memory pressure summary
- swap / VM summary
- top resident-memory processes

### `scan --threshold-gb N`

Lists candidate processes whose RSS is above `N` GB.

### `reap --interactive --threshold-gb N`

Shows candidates and explains the dry-run safety model.

By default, `reap` does not send any signal. To send `TERM`, you must pass `--confirm` and type the target PID exactly. System-critical process names such as `kernel_task`, `launchd`, `WindowServer`, and `loginwindow` are denylisted.

## Safety model

- Diagnostic-first by default.
- No sudo.
- No daemon or LaunchAgent in v0.1.0.
- No automatic killing.
- `reap` is dry-run unless `--confirm` is passed and the PID is typed exactly.
- Protected process names are refused.

## Example

```text
$ ./tahoe-memory-hog-reaper.zsh scan --threshold-gb 1
Candidates above 1GB RSS:
  PID     RSS_GB  PROTECTED  COMMAND
  No process above threshold. Try a lower --threshold-gb value.
```

## Tests

```sh
bash tests/test_tahoe_memory_hog_reaper.sh
```

The test runs shell syntax validation, help/version checks, a high-threshold scan, and a dry-run `reap` path.

## License

MIT
