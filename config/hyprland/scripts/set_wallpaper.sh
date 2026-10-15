#!/usr/bin/env bash
#
# Set the active theme's wallpaper by absolute path and paint it.
# Used by the Quickshell wallpaper switcher (Enter-to-apply).
# Replaces blind cycling: Super+Ctrl+Space now opens the graphical picker.

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=wallpaper-common.sh
. "$SCRIPT_DIR/wallpaper-common.sh"

TARGET="${1:?usage: set_wallpaper.sh <absolute-path>}"
[ -f "$TARGET" ] || exit 0

wp_resolve_theme ""
wp_resolve_dir
wp_list
[ "${#FILES[@]}" -gt 0 ] || exit 0

# Resolve symlinks on both sides so cache-written paths compare equal.
TARGET_REAL="$(realpath -m "$TARGET")"
INDEX=-1
for i in "${!FILES[@]}"; do
  if [ "$(realpath -m "${FILES[$i]}")" = "$TARGET_REAL" ]; then
    INDEX="$i"
    break
  fi
done
[ "$INDEX" -ge 0 ] || exit 0

WALLPAPER="${FILES[$INDEX]}"
INDEX_CACHE="$(wp_index_cache)"
PATH_CACHE="$(wp_path_cache)"

mkdir -p "$(dirname "$INDEX_CACHE")"
printf '%s\n' "$INDEX" > "$INDEX_CACHE"
printf '%s\n' "$WALLPAPER" > "$PATH_CACHE"

wp_paint "$WALLPAPER"
