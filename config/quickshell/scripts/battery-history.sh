#!/usr/bin/env bash
# Battery charge history from the UPower daemon.
# Prints one "epoch percent state" line per sample (state: 0 unknown, 1 charging, 2 discharging).
# Usage: battery-history.sh [timespan_seconds] [resolution_seconds]
set -euo pipefail

SPAN="${1:-43200}"
RES="${2:-120}"

DEV="$(upower -e 2>/dev/null | grep -m1 '/battery_' || true)"
if [ -z "$DEV" ]; then
  DEV="/org/freedesktop/UPower/devices/DisplayDevice"
fi

OUT="$(gdbus call --system --dest org.freedesktop.UPower \
  --object-path "$DEV" \
  --method org.freedesktop.UPower.Device.GetHistory \
  charge "$SPAN" "$RES" 2>/dev/null || true)"

if [ -z "$OUT" ]; then
  exit 0
fi

printf '%s' "$OUT" | tr -d '\n' \
  | sed -E 's/^\(\[//; s/\],\)$/]/; s/uint32 //g' \
  | tr ')' '\n' \
  | sed -nE 's/^[^0-9]*([0-9]+)[^0-9]+([0-9.]+)[^0-9]+([0-9]+).*$/\1 \2 \3/p'
