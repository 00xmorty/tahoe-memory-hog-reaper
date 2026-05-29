# v0.1.0

Initial public draft release of Tahoe Memory Hog Reaper.

## Features

- `status`: memory pressure, VM/swap summary, and top RSS processes.
- `scan --threshold-gb N`: list candidate memory hogs above a threshold.
- `reap --interactive`: safe dry-run path by default.
- Explicit `--confirm` + exact PID typing required before TERM.
- Protected process denylist for system-critical macOS processes.

## Safety

- No sudo.
- No daemon / LaunchAgent.
- No automatic killing.
- Diagnostic-first behavior in v0.1.0.
