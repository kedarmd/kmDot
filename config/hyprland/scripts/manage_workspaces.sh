#!/usr/bin/env bash

LAPTOP="eDP-1"
EXTERNAL="HDMI-A-1"

# get current monitors
ACTIVE=$(hyprctl monitors | awk '/Monitor/ {print $2}')

if echo "$ACTIVE" | grep -q "$EXTERNAL"; then
  # external connected → map 1–4 to external, 5 to laptop
  hyprctl keyword workspace 1 monitor:$EXTERNAL
  hyprctl keyword workspace 2 monitor:$EXTERNAL
  hyprctl keyword workspace 3 monitor:$EXTERNAL
  hyprctl keyword workspace 4 monitor:$EXTERNAL
  hyprctl keyword workspace 5 monitor:$LAPTOP
else
  # external NOT connected → keep everything on laptop
  hyprctl keyword workspace 1 monitor:$LAPTOP
  hyprctl keyword workspace 2 monitor:$LAPTOP
  hyprctl keyword workspace 3 monitor:$LAPTOP
  hyprctl keyword workspace 4 monitor:$LAPTOP
  hyprctl keyword workspace 5 monitor:$LAPTOP
fi

