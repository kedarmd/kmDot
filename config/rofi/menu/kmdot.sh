#!/usr/bin/env bash

set -euo pipefail

export LANG=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8

apps="󰪥  Applications"
connections="󰤨  Connections"
keybinds="󰌌  Keybinds"
system="  System"
themes="  Themes"

options="$apps\n$connections\n$keybinds\n$system\n$themes"

choice=$(printf '%b\n' "$options" | rofi -dmenu -no-show-icons -normal-window -i -p "kmDot")

case "$choice" in
  "$apps")
    rofi -show drun
    ;;
  "$connections")
    "$HOME/.config/kmdot/rofi/menu/connectivity.sh"
    ;;
  "$keybinds")
    "$HOME/.config/kmdot/rofi/menu/keybinds.sh"
    ;;
  "$system")
    "$HOME/.config/kmdot/rofi/menu/system.sh"
    ;;
  "$themes")
    "$HOME/.config/kmdot/rofi/menu/theme-switcher.sh"
    ;;
esac
