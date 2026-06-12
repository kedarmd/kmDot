#!/usr/bin/env bash

current=$(powerprofilesctl get 2>/dev/null)

case "$current" in
  "power-saver")
    icon=""
    label="Echo"
    class="battery"      # <- matches your CSS: #custom-power.battery
    ;;
  "balanced")
    icon=""
    label="Norm"
    class="balanced"
    ;;
  "performance")
    icon=""
    label="Turbo"
    class="performance"
    ;;
  *)
    icon=""
    label="?"
    class="unknown"
    ;;
esac

# Important: include "class" so Waybar can apply CSS like #custom-power.performance
echo "{\"text\": \"$icon $label\", \"tooltip\": \"Power profile: $current\", \"class\": \"$class\"}"
