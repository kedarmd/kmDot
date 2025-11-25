#!/usr/bin/env bash
# Usage: brightness.sh +5%   or brightness.sh 5%-

# Adjust brightness
brightnessctl set "$1" >/dev/null 2>&1

# Compute percent for wob
cur=$(brightnessctl get)
max=$(brightnessctl max)
[ -z "$cur" -o -z "$max" ] && exit 0
value=$(( cur * 100 / max ))

# Send to wob FIFO if available
echo "$value" > /tmp/wobpipe
