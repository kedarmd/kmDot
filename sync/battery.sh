#!/usr/bin/env bash
set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KMDOT_SYSTEMD_DIR="$HOME/.config/systemd/user"

mkdir -p "$KMDOT_SYSTEMD_DIR"

cp "$REPO_DIR/config/systemd/user/battery-monitor.service" "$KMDOT_SYSTEMD_DIR/"
cp "$REPO_DIR/config/systemd/user/battery-monitor.timer" "$KMDOT_SYSTEMD_DIR/"

if systemctl --user show-environment >/dev/null 2>&1; then
  systemctl --user daemon-reload || echo "WARNING: daemon-reload failed" >&2
  systemctl --user enable --now battery-monitor.timer || echo "WARNING: battery timer enable failed" >&2
else
  echo "Skipping systemd enable (no user bus available). Run sync/battery.sh again from a systemd session."
fi

echo "kmDot battery monitor synced!!!"