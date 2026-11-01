#!/usr/bin/env bash
set -euo pipefail

# An updater can replace ~/.local/bin/hex while the old service is still
# running. Query the service's own executable so its CLI and IPC protocol match.
status_cli=""
service_pid="$(systemctl --user show hex.service --property=MainPID --value 2>/dev/null || true)"
if [[ "$service_pid" =~ ^[1-9][0-9]*$ && -x "/proc/$service_pid/exe" ]]; then
  status_cli="/proc/$service_pid/exe"
fi

if [[ -z "$status_cli" ]]; then
  status_cli="$(command -v hex || true)"
fi

if [[ -z "$status_cli" || ! -x "$status_cli" ]]; then
  printf 'Hex is not installed or its service is not running\n' >&2
  exit 1
fi

# Hex 3.1+ defaults to human-readable output and offers --json. Hex 3.0 emits
# JSON by default and rejects that flag. Probe the selected binary's own help.
if "$status_cli" status --help 2>&1 | grep -q -- '--json'; then
  exec "$status_cli" status --json
else
  exec "$status_cli" status
fi
