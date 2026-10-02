#!/usr/bin/env bash
set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KMDOT_SYSTEMD_DIR="$HOME/.config/systemd/user"

mkdir -p "$KMDOT_SYSTEMD_DIR"

cp "$REPO_DIR/config/systemd/user/battery-monitor.service" "$KMDOT_SYSTEMD_DIR/"
cp "$REPO_DIR/config/systemd/user/battery-monitor.timer" "$KMDOT_SYSTEMD_DIR/"

if systemctl --user show-environment >/dev/null 2>&1; then
  systemctl --user daemon-reload
  systemctl --user enable --now battery-monitor.timer
else
  echo "Skipping systemd enable (no user bus available). Run sync/battery.sh again from a systemd session."
fi

echo "kmDot battery monitor synced!!!"