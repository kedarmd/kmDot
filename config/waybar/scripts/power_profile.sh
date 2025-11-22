#!/usr/bin/env bash

# Power profile toggle for Waybar using system76-power

# internal names for system76-power
NAMES=(battery balanced performance)
# pretty labels to display
LABELS=("Battery" "Balanced" "Performance")
# icons for each mode
ICONS=("󰁹" "⚖" "󱐌")

# Get CURRENT profile from "Power Profile: Balanced"
CURRENT_RAW=$(system76-power profile 2>/dev/null | awk -F': ' '/Power Profile/ {print $2}')

# Default to first (battery) if parsing fails
idx=0

# Find current index in NAMES / LABELS
for i in "${!NAMES[@]}"; do
  if [[ "${NAMES[$i],,}" == "${CURRENT_RAW,,}" ]] || [[ "${LABELS[$i],,}" == "${CURRENT_RAW,,}" ]]; then
    idx=$i
    break
  fi
done

# If called with "next", go to next profile
if [[ "$1" == "next" ]]; then
  idx=$(((idx + 1) % ${#NAMES[@]}))
  system76-power profile "${NAMES[$idx]}" >/dev/null 2>&1
fi

label="${LABELS[$idx]}"
icon="${ICONS[$idx]}"
class="${NAMES[$idx]}"   # battery | balanced | performance

# Waybar custom module JSON
printf '{"text": "%s %s", "tooltip": "Power: %s", "class": "%s"}\n' \
  "$icon" "$label" "$label" "$class"

