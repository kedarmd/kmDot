#!/usr/bin/env bash

# Exit on Error
set -e

CONFIG_FILE="$HOME/.config/kmdot/waybar/colors.css"
THEME="$1"
COLORSCHEME_FILE="$HOME/.config/kmdot/themes/$THEME/waybar.css"

# Check if theme file exists
if [ ! -f "$COLORSCHEME_FILE" ]; then
  echo "ERROR: Theme '$THEME' does not exist for waybar."
  exit 1
fi

cat "$COLORSCHEME_FILE" > "$CONFIG_FILE"

# Reload waybar to apply the new theme
pkill waybar && waybar &

echo "✓ Waybar theme updated to: $THEME"
