#!/usr/bin/env bash

# Exit on Error
set -e

CONFIG_FILE="$HOME/.config/kmdot/hyprland/theme.conf"
THEME="$1"
THEME_FILE="$HOME/.config/kmdot/themes/$THEME/hyprland.conf"

# Check if theme file exists
if [ ! -f "$THEME_FILE" ]; then
  echo "ERROR: Theme '$THEME' does not exist for hyprland."
  exit 1
fi

cat "$THEME_FILE" > "$CONFIG_FILE"

hyprctl reload

echo "✓ Hyprland theme updated to: $THEME"
