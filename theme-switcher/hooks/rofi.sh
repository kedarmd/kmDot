#!/usr/bin/env bash

# Exit on Error
set -e

CONFIG_FILE="$HOME/.config/kmdot/rofi/theme.rasi"
THEME="$1"
COLORSCHEME_FILE="$HOME/.config/kmdot/themes/$THEME/rofi.rasi"

# Check if theme file exists
if [ ! -f "$COLORSCHEME_FILE" ]; then
  echo "ERROR: Theme '$THEME' does not exist."
  exit 1
fi

cat "$COLORSCHEME_FILE" > "$CONFIG_FILE"


