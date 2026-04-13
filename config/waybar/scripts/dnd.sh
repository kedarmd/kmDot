#!/usr/bin/env bash

set -euo pipefail

if ! command -v swaync-client >/dev/null 2>&1; then
  echo '{"text": "󰂚", "tooltip": "swaync-client not found", "class": ["dnd", "error"]}'
  exit 0
fi

state=$(swaync-client -D -sw 2>/dev/null | tr -d '\r\n') || state=""
count=$(swaync-client -c -sw 2>/dev/null | tr -d '\r\n') || count="0"
[ -z "$count" ] && count="0"

classes=(dnd)
text_output=""

if [ "$state" = "true" ]; then
  icon="󰂛"
  tooltip="Do Not Disturb enabled"
  classes+=(on)
  if [ "$count" -gt 0 ] 2>/dev/null; then
    classes+=(pending)
    tooltip="$tooltip • $count pending notifications"
  fi
else
  icon="󰂚"
  tooltip="Do Not Disturb disabled"
  classes+=(off)
fi

text_output="$icon"
if [ "$count" -gt 0 ] 2>/dev/null; then
  text_output="$icon $count"
fi

class_json=$(printf '"%s",' "${classes[@]}")
class_json=${class_json%,}

printf '{"text": "%s", "tooltip": "%s", "class": [%s]}\n' \
  "$text_output" "$tooltip" "$class_json"
