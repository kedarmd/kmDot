#!/usr/bin/env bash
set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
QUICKSHELL_CONFIG_DIR="$HOME/.config/quickshell"
KMDOT_QUICKSHELL_CONFIG_DIR="$HOME/.config/kmdot/quickshell"

mkdir -p "$HOME/.config/kmdot"

rm -rf "$KMDOT_QUICKSHELL_CONFIG_DIR"
rm -rf "$QUICKSHELL_CONFIG_DIR"

cp -r "$REPO_DIR/config/quickshell" "$KMDOT_QUICKSHELL_CONFIG_DIR"

# Repo files written by the editor default to 0644; scripts must be executable
# or systemd units / cron / etc. fail to spawn them (systemd-inhibit once
# exited status=1 because a spawned script wasn't +x).
chmod +x "$KMDOT_QUICKSHELL_CONFIG_DIR/scripts/"*.sh

ln -sf "$KMDOT_QUICKSHELL_CONFIG_DIR" "$QUICKSHELL_CONFIG_DIR"

if [ -n "${WAYLAND_DISPLAY:-}" ] && command -v wl-paste >/dev/null 2>&1; then
  "$KMDOT_QUICKSHELL_CONFIG_DIR/scripts/clipboard-daemon.sh" >/dev/null 2>&1 &
fi

echo "kmDot quickshell config synced!!!"
