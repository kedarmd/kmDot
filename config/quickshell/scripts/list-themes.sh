#!/usr/bin/env bash
# List installed themes with their canonical quickshell palette roles. The active
# marker comes from ~/.cache/kmdot_theme. ThemeLauncher.qml consumes this via
# SplitParser so palette previews always use the theme config as their source.
set -euo pipefail

THEME_DIR="${HOME}/.config/kmdot/themes"
ACTIVE="$(cat "${HOME}/.cache/kmdot_theme" 2>/dev/null || true)"

if [[ ! -d "$THEME_DIR" ]]; then
  exit 0
fi

while IFS= read -r t; do
  conf="${THEME_DIR}/${t}/quickshell.conf"
  [[ -f "$conf" ]] || continue
  if [[ "$t" == "$ACTIVE" ]]; then
    marker=ACTIVE
  else
    marker=""
  fi
  printf '%s\t%s' "$marker" "$t"
  for key in base surface surface_alt surface_high surface_highest primary_container on_primary_container text text_alt muted border primary primary_alt accent success warning error; do
    value="$(sed -n "s/^${key}=//p" "$conf" | head -n 1)"
    printf '\t%s' "$value"
  done
  printf '\n'
done < <(find "$THEME_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
