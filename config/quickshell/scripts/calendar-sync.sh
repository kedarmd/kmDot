#!/usr/bin/env bash
# Fetch the Google Calendar ICS feed into ~/.cache/kmdot/calendar.ics.
# The private iCal URL lives in ~/.config/kmdot/calendar-url (first line),
# from Google Calendar > Settings > ... > Settings and sharing > Secret address in iCal format.
# No URL file => no-op (the calendar UI just shows the month grid with no events).
set -euo pipefail

URL_FILE="$HOME/.config/kmdot/calendar-url"
CACHE_DIR="$HOME/.cache/kmdot"
ICS="$CACHE_DIR/calendar.ics"

mkdir -p "$CACHE_DIR"

if [[ ! -f "$URL_FILE" ]]; then
  [[ -f "$ICS" ]] || : > "$ICS"
  exit 0
fi

URL="$(head -n1 "$URL_FILE" | tr -d '[:space:]')"
if [[ -z "$URL" ]]; then
  exit 0
fi

# Without --force, skip when the cache is fresh (< 30 min old).
MAX_AGE=1800
if [[ "${1:-}" != "--force" ]] && [[ -f "$ICS" ]]; then
  if [[ $(( $(date +%s) - $(stat -c %Y "$ICS") )) -lt $MAX_AGE ]]; then
    exit 0
  fi
fi

if curl -fsSL --max-time 25 "$URL" -o "$ICS.tmp"; then
  mv "$ICS.tmp" "$ICS"
else
  rm -f "$ICS.tmp"
fi
