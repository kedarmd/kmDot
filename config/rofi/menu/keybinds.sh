#!/usr/bin/env bash

set -euo pipefail

export LANG=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8

KEYBINDS_FILE="$HOME/.config/kmdot/hyprland/keybinds.lua"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -f "$KEYBINDS_FILE" ]; then
  notify-send "Keybinds" "keybinds.lua not found: $KEYBINDS_FILE"
  exit 1
fi

list=$(lua "$SCRIPT_DIR/keybinds.lua" "$KEYBINDS_FILE")

printf '%s\n' "$list" | rofi -dmenu -no-show-icons -normal-window -i -p "Keybinds"

exit 0
