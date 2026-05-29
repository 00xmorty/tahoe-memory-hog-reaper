#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/tahoe-memory-hog-reaper.zsh"

zsh -n "$SCRIPT"

help_output="$($SCRIPT help)"
[[ "$help_output" == *"Tahoe Memory Hog Reaper"* ]]
[[ "$help_output" == *"Diagnostic by default"* ]]

version_output="$($SCRIPT --version)"
[[ "$version_output" == *"0.1.0"* ]]

scan_output="$($SCRIPT scan --threshold-gb 9999)"
[[ "$scan_output" == *"Candidates above 9999GB RSS"* ]]
[[ "$scan_output" == *"No process above threshold"* ]]

reap_output="$($SCRIPT reap --interactive --threshold-gb 9999)"
[[ "$reap_output" == *"Dry-run safety"* ]]

echo "test_tahoe_memory_hog_reaper: ok"
