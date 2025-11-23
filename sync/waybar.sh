#!/usr/bin/env bash
set -e

WAYBAR_CONFIG_DIR="$HOME/.config/waybar"
KMDOT_WAYBAR_CONFIG_DIR="$HOME/.config/kmdot/waybar"

if [ ! -e "$WAYBAR_CONFIG_DIR" ]; then
  echo "No waybar config available. Adding kmDot waybar config"
  ln -sf "$KMDOT_WAYBAR_CONFIG_DIR" "$WAYBAR_CONFIG_DIR"
  exit 0
fi

echo "INFO: WAYBAR config already exists"

WAYBAR_SOURCE=$(readlink "$WAYBAR_CONFIG_DIR")
if [ "$WAYBAR_SOURCE" != "$KMDOT_WAYBAR_CONFIG_DIR" ]; then
   echo "WARNING: Current symlink doesn't point to kmDot waybar. Reconfiguring..."
   rm -f "$WAYBAR_CONFIG_DIR"
   ln -sf "$KMDOT_WAYBAR_CONFIG_DIR" "$WAYBAR_CONFIG_DIR"
   echo "kmDot waybar config synced!!!"
   exit 0
fi

