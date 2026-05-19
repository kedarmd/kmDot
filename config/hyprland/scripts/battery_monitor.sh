#!/usr/bin/env bash

BATTERY_PATH="/sys/class/power_supply/BAT0"
THRESHOLD=20

if [[ ! -d "$BATTERY_PATH" ]]; then
  BATTERY_PATH="/sys/class/power_supply/BAT1"
fi

if [[ ! -d "$BATTERY_PATH" ]]; then
  exit 0
fi

capacity=$(cat "$BATTERY_PATH/capacity" 2>/dev/null)
status=$(cat "$BATTERY_PATH/status" 2>/dev/null)

if [[ "$status" == "Discharging" && "${capacity:-100}" -le "$THRESHOLD" ]]; then
  powerprofilesctl set power-saver
  notify-send -u critical "Battery Low" "Battery at ${capacity}% - Power saver mode enabled"
fi