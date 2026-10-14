#!/usr/bin/env bash
#
# Advance the active theme's wallpaper cycle by one and paint it.
# Bound to Super+CTRL+SPACE.
#
#   cycle_wallpapers.sh [theme] [--first]
#
# --first resets the cycle to wallpaper 01 instead of advancing. The theme
# switcher uses it so every theme switch lands on that theme's first wallpaper.

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=wallpaper-common.sh
. "$SCRIPT_DIR/wallpaper-common.sh"

THEME_ARG=""
RESET=0

for arg in "$@"; do
  case "$arg" in
    --first) RESET=1 ;;
    -*) ;;
    *) [ -n "$THEME_ARG" ] || THEME_ARG="$arg" ;;
  esac
done

wp_resolve_theme "$THEME_ARG"
wp_resolve_dir

INDEX_CACHE="$(wp_index_cache)"
PATH_CACHE="$(wp_path_cache)"
wp_migrate_cache "$INDEX_CACHE" "$HOME/.cache/hyprpaper_wallpaper_index_${THEME:-default}"
wp_migrate_cache "$PATH_CACHE" "$HOME/.cache/hyprpaper_wallpaper_${THEME:-default}"

wp_list
TOTAL=${#FILES[@]}
[ "$TOTAL" -eq 0 ] && exit 0

if [ "$RESET" -eq 1 ]; then
  INDEX=0
else
  # Start at -1 so the first run lands on index 0.
  INDEX=-1
  if [ -f "$INDEX_CACHE" ]; then
    INDEX="$(cat "$INDEX_CACHE" 2>/dev/null)"
    [[ "$INDEX" =~ ^[0-9]+$ ]] || INDEX=-1
  fi
  INDEX=$(( (INDEX + 1) % TOTAL ))
fi

WALLPAPER="${FILES[$INDEX]}"

mkdir -p "$(dirname "$INDEX_CACHE")"
printf '%s\n' "$INDEX" > "$INDEX_CACHE"
printf '%s\n' "$WALLPAPER" > "$PATH_CACHE"

wp_paint "$WALLPAPER"
