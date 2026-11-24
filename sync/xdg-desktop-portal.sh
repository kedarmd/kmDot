#!/usr/bin/env bash
set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PORTAL_CONFIG_DIR="$HOME/.config/xdg-desktop-portal"
KMDOT_PORTAL_CONFIG_DIR="$HOME/.config/kmdot/xdg-desktop-portal"

mkdir -p "$HOME/.config/kmdot"

rm -rf "$KMDOT_PORTAL_CONFIG_DIR"
rm -rf "$PORTAL_CONFIG_DIR"

cp -r "$REPO_DIR/config/xdg-desktop-portal" "$KMDOT_PORTAL_CONFIG_DIR"

ln -sf "$KMDOT_PORTAL_CONFIG_DIR" "$PORTAL_CONFIG_DIR"

# GTK applications read the desktop preference from GSettings;
# ADW_COLOR_SCHEME alone does not change that system setting.
if command -v gsettings >/dev/null 2>&1 \
  && gsettings list-schemas | grep -qx org.gnome.desktop.interface; then
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
fi

echo "kmDot xdg-desktop-portal config synced!!!"
