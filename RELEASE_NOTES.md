# v0.1.0

Initial public draft release of Tahoe Memory Hog Reaper.

## What it does

Tahoe Memory Hog Reaper is a tiny, safe macOS CLI for spotting runaway memory hogs before your Mac hits “out of application memory”.

## Features

- `status`: memory pressure, VM/swap summary, and top RSS processes.
- `scan --threshold-gb N`: list candidate memory hogs above a threshold.
- `reap --interactive`: safe dry-run path by default.
- Explicit `--confirm` + exact PID typing required before TERM.
- Protected process denylist for system-critical macOS processes.
- Terminal demo GIF and expanded README added for public launch.

## Safety

- No sudo.
- No daemon / LaunchAgent.
- No automatic killing.
- Diagnostic-first behavior in v0.1.0.

## Verification

- Local smoke test: passing.
- GitHub Actions macOS CI: passing.
