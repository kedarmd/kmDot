#!/usr/bin/env bash

# Ordinal day suffix function
day=$(date +%-d)
case "$day" in
  1|21|31) suffix="st" ;;
  2|22)    suffix="nd" ;;
  3|23)    suffix="rd" ;;
  *)       suffix="th" ;;
esac

# Output in Waybar JSON format
formatted=$(date +"%a ${day}${suffix} %b - %I:%M %p")
echo "{\"text\": \"$formatted\"}"

