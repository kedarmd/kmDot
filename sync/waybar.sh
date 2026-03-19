#!/usr/bin/env bash
set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WAYBAR_CONFIG_DIR="$HOME/.config/waybar"
KMDOT_WAYBAR_CONFIG_DIR="$HOME/.config/kmdot/waybar"

mkdir -p "$HOME/.config/kmdot"

rm -rf "$KMDOT_WAYBAR_CONFIG_DIR"
rm -rf "$WAYBAR_CONFIG_DIR"

cp -r "$REPO_DIR/config/waybar" "$KMDOT_WAYBAR_CONFIG_DIR"

ln -sf "$KMDOT_WAYBAR_CONFIG_DIR" "$WAYBAR_CONFIG_DIR"

echo "kmDot waybar config synced!!!"

