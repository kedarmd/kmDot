#!/usr/bin/env bash

shutdown="  Shutdown"
restart="  Restart"
suspend="  Suspend"
logout="  Logout"
options="$shutdown\n$restart\n$suspend\n$logout"

choice=$(echo -e "$options" | rofi -dmenu -normal-window -i -p "System Menu" -theme-str 'element-icon { width: 0px; padding: 0px; margin: 0px; } element-icon selected { width: 0px; padding: 0px; margin: 0px; }')

case "$choice" in
  "$shutdown")
    systemctl poweroff
    ;;
  "$restart")
    systemctl reboot
    ;;
  "$suspend")
    systemctl suspend
    ;;
  "$logout")
    hyprctl dispatch exit
    ;;
esac
