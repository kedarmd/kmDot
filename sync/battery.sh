#!/usr/bin/env bash
set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KMDOT_SYSTEMD_DIR="$HOME/.config/systemd/user"

mkdir -p "$KMDOT_SYSTEMD_DIR"

cp "$REPO_DIR/config/systemd/user/battery-monitor.service" "$KMDOT_SYSTEMD_DIR/"
cp "$REPO_DIR/config/systemd/user/battery-monitor.timer" "$KMDOT_SYSTEMD_DIR/"

echo "kmDot battery monitor synced!!!"