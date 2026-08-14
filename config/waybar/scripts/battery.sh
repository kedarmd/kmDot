#!/usr/bin/env bash

set -euo pipefail

cap=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null) || cap=0
status=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null) || status="Unknown"

if [ "$cap" -le 20 ]; then
  icon=""
elif [ "$cap" -le 40 ]; then
  icon=""
elif [ "$cap" -le 60 ]; then
  icon=""
elif [ "$cap" -le 80 ]; then
  icon=""
else
  icon=""
fi

profile=$(powerprofilesctl get 2>/dev/null) || profile="unknown"

classes=(battery)
text="$icon $cap%"
tooltip="Battery: $cap% ($status)"

if [ "$status" = "Discharging" ]; then
  time_left=$(upower -i /org/freedesktop/UPower/devices/battery_BAT0 2>/dev/null \
    | awk '/time to empty/ {print $4, $5}')
  if [ -n "$time_left" ] && [ "${time_left%% *}" != "0" ]; then
    tooltip="$tooltip\nTime remaining: $time_left"
  fi
fi

tooltip="$tooltip\nPower profile: $profile"

if [ "$status" = "Charging" ] || [ "$status" = "Full" ]; then
  text=" $cap%"
  classes+=(charging)
elif [ "$cap" -le 15 ]; then
  classes+=(critical)
elif [ "$cap" -le 30 ]; then
  classes+=(warning)
fi

class_json=$(printf '"%s",' "${classes[@]}")
class_json=${class_json%,}

printf '{"text": "%s", "tooltip": "%s", "class": [%s]}\n' \
  "$text" "$tooltip" "$class_json"