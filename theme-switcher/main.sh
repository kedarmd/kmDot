#!/usr/bin/env bash

# Exit on Error
set -e

# --- 1. Define the directory where this script is located ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

THEME="$1"

# --- 2. Use the absolute path for sourcing the hook scripts ---
. "$SCRIPT_DIR/hooks/nvim.sh" "$THEME"
# . "$SCRIPT_DIR/hooks/wezterm.sh" "$THEME"
. "$SCRIPT_DIR/hooks/starship.sh" "$THEME"
. "$SCRIPT_DIR/hooks/rofi.sh" "$THEME"
. "$SCRIPT_DIR/hooks/ghostty.sh" "$THEME"
. "$SCRIPT_DIR/hooks/waybar.sh" "$THEME"
