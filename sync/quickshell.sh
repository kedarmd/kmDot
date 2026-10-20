#!/usr/bin/env bash
set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
QUICKSHELL_CONFIG_DIR="$HOME/.config/quickshell"
KMDOT_QUICKSHELL_CONFIG_DIR="$HOME/.config/kmdot/quickshell"

# Resolve an explicitly selected theme before touching the deployed configuration.
THEME="${1:-$(cat "$HOME/.cache/kmdot_theme" 2>/dev/null || true)}"
if [[ ! "$THEME" =~ ^[a-z][a-z0-9_-]*$ ]] || [[ ! -f "$REPO_DIR/themes/$THEME/quickshell.conf" ]]; then
  echo "ERROR: Select a theme first, or run sync/quickshell.sh <theme>. No default palette is installed." >&2
  exit 1
fi
PALETTE_TEMP="$(mktemp)"
trap 'rm -f "$PALETTE_TEMP"' EXIT
"$REPO_DIR/theme-switcher/render-quickshell.sh" "$REPO_DIR/themes/$THEME/quickshell.conf" > "$PALETTE_TEMP"
mkdir -p "$HOME/.config/kmdot"

rm -rf "$KMDOT_QUICKSHELL_CONFIG_DIR"
rm -rf "$QUICKSHELL_CONFIG_DIR"

cp -r "$REPO_DIR/config/quickshell" "$KMDOT_QUICKSHELL_CONFIG_DIR"
install -m644 "$PALETTE_TEMP" "$KMDOT_QUICKSHELL_CONFIG_DIR/Colors.qml"

# Repo files written by the editor default to 0644; scripts must be executable
# or systemd units / cron / etc. fail to spawn them (systemd-inhibit once
# exited status=1 because a spawned script wasn't +x).
chmod +x "$KMDOT_QUICKSHELL_CONFIG_DIR/scripts/"*.sh

ln -sf "$KMDOT_QUICKSHELL_CONFIG_DIR" "$QUICKSHELL_CONFIG_DIR"

if [ -n "${WAYLAND_DISPLAY:-}" ] && command -v wl-paste >/dev/null 2>&1; then
  "$KMDOT_QUICKSHELL_CONFIG_DIR/scripts/clipboard-daemon.sh" >/dev/null 2>&1 &
fi

echo "kmDot quickshell config synced!!!"
