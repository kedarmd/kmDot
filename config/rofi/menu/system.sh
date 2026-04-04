#!/usr/bin/env bash

lock="  Lock"
logout="  Logout"
restart="  Restart"
shutdown="  Shutdown"
suspend="  Suspend"
options="$lock\n$logout\n$restart\n$shutdown\n$suspend"

choice=$(echo -e "$options" | rofi -dmenu -no-show-icons -normal-window -i -p "System Menu")

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
  "$lock")
    hyprlock
    ;;
  "$logout")
    hyprctl dispatch exit
    ;;
esac
