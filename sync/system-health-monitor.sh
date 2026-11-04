#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BIN_DIR="$HOME/.local/bin"
USER_UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"

install -Dm755 "$REPO_DIR/config/system-health-monitor/system-health-monitor.sh" \
  "$BIN_DIR/kmdot-system-health-monitor.sh"
install -Dm644 "$REPO_DIR/config/systemd/user/system-health-monitor.service" \
  "$USER_UNIT_DIR/system-health-monitor.service"

if systemctl --user show-environment >/dev/null 2>&1; then
  systemctl --user daemon-reload
  if systemctl --user is-active --quiet system-health-monitor.service; then
    systemctl --user restart system-health-monitor.service
  else
    systemctl --user enable --now system-health-monitor.service
  fi
  echo "System health monitor enabled. Logs: ${XDG_STATE_HOME:-$HOME/.local/state}/kmdot/system-health/"
else
  echo "Files installed. Start it from a logged-in session with:"
  echo "  systemctl --user daemon-reload && systemctl --user enable --now system-health-monitor.service"
fi
