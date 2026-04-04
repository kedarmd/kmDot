#!/usr/bin/env bash

THEMES_DIR="$HOME/.config/kmdot/themes"
CACHE_THEME_FILE="$HOME/.cache/kmdot_theme"
THEME="${1:-$(cat "$CACHE_THEME_FILE" 2>/dev/null)}"

if [ -z "$THEME" ] && [ -d "$THEMES_DIR" ]; then
  THEME="$(ls -1 "$THEMES_DIR" 2>/dev/null | head -n 1)"
fi

WALLPAPERS_DIR="$THEMES_DIR/$THEME/wallpapers"
if [ ! -d "$WALLPAPERS_DIR" ]; then
  WALLPAPERS_DIR="$HOME/Pictures"
fi

CACHE_FILE="$HOME/.cache/hyprpaper_wallpaper_index_${THEME:-default}"
CACHE_WALLPAPER_FILE="$HOME/.cache/hyprpaper_wallpaper_${THEME:-default}"

# Collect wallpapers (non-random, sorted)
mapfile -t FILES < <(find "$WALLPAPERS_DIR" -maxdepth 1 -type f \
  \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) | sort)

TOTAL=${#FILES[@]}
[ "$TOTAL" -eq 0 ] && exit 0

# Read index or start at -1 so first run uses index 0
if [ -f "$CACHE_FILE" ]; then
  INDEX=$(cat "$CACHE_FILE")
else
  INDEX=-1
fi

# Advance index and wrap
INDEX=$(( (INDEX + 1) % TOTAL ))
echo "$INDEX" > "$CACHE_FILE"

WALLPAPER="${FILES[$INDEX]}"

mkdir -p "$(dirname "$CACHE_WALLPAPER_FILE")"
echo "$WALLPAPER" > "$CACHE_WALLPAPER_FILE"

if ! pgrep -x awww-daemon >/dev/null 2>&1; then
  nohup awww-daemon >/dev/null 2>&1 &
  sleep 0.2
fi

awww img "$WALLPAPER" \
  --transition-type grow \
  --transition-duration 1 \
  --transition-fps 60 \
  >/dev/null 2>&1
