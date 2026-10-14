#!/usr/bin/env bash
#
# Paint the active theme's current wallpaper. Runs from autostart at login,
# so with no cache it starts every session on wallpaper 01.

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=wallpaper-common.sh
. "$SCRIPT_DIR/wallpaper-common.sh"

wp_resolve_theme "${1:-}"
wp_resolve_dir

PATH_CACHE="$(wp_path_cache)"
wp_migrate_cache "$PATH_CACHE" "$HOME/.cache/hyprpaper_wallpaper_${THEME:-default}"

# A cached path left over from a rename no longer exists on disk, which falls
# through to the first wallpaper below.
WALLPAPER=""
if [ -f "$PATH_CACHE" ]; then
  WALLPAPER="$(cat "$PATH_CACHE")"
fi

if [ -z "$WALLPAPER" ] || [ ! -f "$WALLPAPER" ]; then
  wp_list
  [ "${#FILES[@]}" -eq 0 ] && exit 0
  WALLPAPER="${FILES[0]}"
fi

wp_paint "$WALLPAPER"
