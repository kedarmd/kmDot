#!/usr/bin/env bash
# List the active theme's wallpapers for the Quickshell wallpaper switcher.
# Output per line: marker<TAB>id<TAB>path<TAB>dimensions<TAB>theme, in cycle
# order (sort -V). Marker is ACTIVE for the current wallpaper, else empty.
# WallpaperLauncher.qml consumes this via SplitParser.
set -euo pipefail

THEMES_DIR="${HOME}/.config/kmdot/themes"
THEME="$(cat "${HOME}/.cache/kmdot_theme" 2>/dev/null || true)"
DIR="$THEMES_DIR/$THEME/wallpapers"

[ -n "$THEME" ] && [ -d "$DIR" ] || exit 0

ACTIVE="$(cat "${HOME}/.cache/kmdot_wallpaper_${THEME}" 2>/dev/null || true)"

while IFS= read -r f; do
  [ -n "$f" ] || continue
  base="$(basename "$f")"
  id="${base%.*}"
  marker=""
  [ "$f" = "$ACTIVE" ] && marker="ACTIVE"
  # Read headers only; decoding these multi-megapixel images delays every open.
  dims=""
  if command -v identify >/dev/null 2>&1; then
    dims="$(identify -ping -format '%wx%h' "$f" 2>/dev/null || true)"
  elif command -v magick >/dev/null 2>&1; then
    dims="$(magick identify -ping -format '%wx%h' "$f" 2>/dev/null || true)"
  fi
  printf '%s\t%s\t%s\t%s\t%s\n' "$marker" "$id" "$f" "$dims" "$THEME"
done < <(find "$DIR" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | LC_ALL=C sort -V)
