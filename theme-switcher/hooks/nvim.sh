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

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
THEME_SWITCHER_DIR="$(cd "$HOOK_DIR/.." && pwd -P)"
UTIL_SCRIPT="$THEME_SWITCHER_DIR/utils/change-nvim-theme-live.sh"
if [ ! -x "$UTIL_SCRIPT" ]; then
  echo "ERROR: Missing executable $UTIL_SCRIPT"
  exit 1
fi
"$UTIL_SCRIPT" "$THEME"
