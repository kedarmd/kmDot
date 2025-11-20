#!/usr/bin/env bash

# Exit on Error
set -e

CONFIG_FILE="$HOME/.config/kmdot/nvim/lua/plugins/colorscheme.lua"
THEME="$1"
COLORSCHEME_FILE="$HOME/.config/kmdot/themes/$THEME/nvim.lua"

# Check if theme file exists
if [ ! -f "$COLORSCHEME_FILE" ]; then
  echo "ERROR: Theme '$THEME' does not exist."
  exit 1
fi

cat "$COLORSCHEME_FILE" > "$CONFIG_FILE"

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
"$SCRIPT_DIR/utils/change-nvim-theme-live.sh" "$THEME"
