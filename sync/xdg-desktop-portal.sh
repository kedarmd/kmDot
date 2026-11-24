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

# Set the desktop color preference for apps that follow it.
if command -v gsettings >/dev/null 2>&1 \
  && gsettings list-schemas | grep -qx org.gnome.desktop.interface; then
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
fi

# GTK 3 file pickers use the portal process's GTK theme.
PORTAL_GTK_OVERRIDE="systemd/user/xdg-desktop-portal-gtk.service.d/theme.conf"
install -Dm644 "$REPO_DIR/config/$PORTAL_GTK_OVERRIDE" "${XDG_CONFIG_HOME:-$HOME/.config}/$PORTAL_GTK_OVERRIDE"
if systemctl --user daemon-reload; then
  systemctl --user try-restart xdg-desktop-portal-gtk.service
fi

echo "kmDot xdg-desktop-portal config synced!!!"
