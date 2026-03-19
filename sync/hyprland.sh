#!/usr/bin/env bash
set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HYPRLAND_CONFIG_DIR="$HOME/.config/hypr"
KMDOT_HYPRLAND_CONFIG_DIR="$HOME/.config/kmdot/hyprland"

mkdir -p "$HOME/.config/kmdot"

rm -rf "$KMDOT_HYPRLAND_CONFIG_DIR"
rm -rf "$HYPRLAND_CONFIG_DIR"

cp -r "$REPO_DIR/config/hyprland" "$KMDOT_HYPRLAND_CONFIG_DIR"

ln -sf "$KMDOT_HYPRLAND_CONFIG_DIR" "$HYPRLAND_CONFIG_DIR"

echo "kmDot hyprland config synced!!!"

