#!/usr/bin/env bash

set -euo pipefail

export LANG=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8

bluetooth="󰂯  Bluetooth"
wifi="󰤨  Wifi"

options="$bluetooth\n$wifi"

choice=$(printf '%b\n' "$options" | rofi -dmenu -no-show-icons -normal-window -i -p "Connections")

case "$choice" in
  "$bluetooth")
    blueman-manager
    ;;
  "$wifi")
    "$HOME/.config/kmdot/rofi/menu/wifi.sh"
    ;;
esac
