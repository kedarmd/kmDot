#!/usr/bin/env bash
set -e

HYPRLAND_CONFIG_DIR="$HOME/.config/hypr"
KMDOT_HYPRLAND_CONFIG_DIR="$HOME/.config/kmdot/hyprland"

if [ ! -e "$HYPRLAND_CONFIG_DIR" ]; then
  echo "No hyprland config available. Adding kmDot hyprland config"
  ln -sf "$KMDOT_HYPRLAND_CONFIG_DIR" "$HYPRLAND_CONFIG_DIR"
  exit 0
fi

echo "INFO: HYPRLAND config already exists"

HYPRLAND_SOURCE=$(readlink "$HYPRLAND_CONFIG_DIR")
if [ "$HYPRLAND_SOURCE" != "$KMDOT_HYPRLAND_CONFIG_DIR" ]; then
   echo "WARNING: Current symlink doesn't point to kmDot hyprland. Reconfiguring..."
   rm -f "$HYPRLAND_CONFIG_DIR"
   ln -sf "$KMDOT_HYPRLAND_CONFIG_DIR" "$HYPRLAND_CONFIG_DIR"
   echo "kmDot hyprland config synced!!!"
   exit 0
fi

