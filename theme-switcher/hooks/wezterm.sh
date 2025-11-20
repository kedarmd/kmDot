#!/usr/bin/env bash

# Exit on Error
set -e

CONFIG_FILE="$HOME/.config/kmdot/wezterm/theme.lua"
SOURCE_DIR="$HOME/.config/kmdot/themes"

THEME="$1"

# Check if theme file exists
COLORSCHEME_FILE="$SOURCE_DIR/$THEME/wezterm.lua" 
if [ ! -f "$COLORSCHEME_FILE" ]; then
  echo "ERROR: Theme '$THEME' does not exist."
  exit 1
fi

cat "$COLORSCHEME_FILE" > "$CONFIG_FILE"

# Reload wezterm config
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
"$SCRIPT_DIR/../utils/reload-wezterm-config.sh"
