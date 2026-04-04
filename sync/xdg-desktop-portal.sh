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

echo "kmDot xdg-desktop-portal config synced!!!"
