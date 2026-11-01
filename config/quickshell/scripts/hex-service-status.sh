#!/usr/bin/env bash
set -euo pipefail

# The Hex updater can switch ~/.local/bin/hex before its running service is
# restarted. In that window, query the executable backing the service so the
# CLI and its IPC protocol stay on the same version.
pid="$(systemctl --user show hex.service --property=MainPID --value 2>/dev/null || true)"
if [[ ! "$pid" =~ ^[1-9][0-9]*$ || ! -x "/proc/$pid/exe" ]]; then
  exit 1
fi

service_cli="/proc/$pid/exe"
if status_json="$("$service_cli" status --json 2>/dev/null)"; then
  printf '%s\n' "$status_json"
  exit 0
fi

# Hex 3.0 emitted JSON by default and did not accept the --json flag.
exec "$service_cli" status
