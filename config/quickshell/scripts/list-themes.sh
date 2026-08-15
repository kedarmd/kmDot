#!/usr/bin/env bash
# List installed themes, one per line as "<marker>\t<name>" where marker is
# ACTIVE for the currently active theme (from ~/.cache/kmdot_theme). Consumed by
# ThemeLauncher.qml via SplitParser.
set -euo pipefail

THEME_DIR="${HOME}/.config/kmdot/themes"
ACTIVE="$(cat "${HOME}/.cache/kmdot_theme" 2>/dev/null || true)"

if [[ ! -d "$THEME_DIR" ]]; then
  exit 0
fi

while IFS= read -r t; do
  if [[ "$t" == "$ACTIVE" ]]; then
    printf 'ACTIVE\t%s\n' "$t"
  else
    printf '\t%s\n' "$t"
  fi
done < <(find "$THEME_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
