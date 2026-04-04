#!/usr/bin/env bash

THEMES_DIR="$HOME/.config/kmdot/themes"
CACHE_THEME_FILE="$HOME/.cache/kmdot_theme"
THEME="$(cat "$CACHE_THEME_FILE" 2>/dev/null)"

if [ -z "$THEME" ] && [ -d "$THEMES_DIR" ]; then
  THEME="$(ls -1 "$THEMES_DIR" 2>/dev/null | head -n 1)"
fi

WALLPAPERS_DIR="$THEMES_DIR/$THEME/wallpapers"
if [ ! -d "$WALLPAPERS_DIR" ]; then
  WALLPAPERS_DIR="$HOME/Pictures"
fi

CACHE_WALLPAPER_FILE="$HOME/.cache/hyprpaper_wallpaper_${THEME:-default}"
WALLPAPER=""

if [ -f "$CACHE_WALLPAPER_FILE" ]; then
  WALLPAPER="$(cat "$CACHE_WALLPAPER_FILE")"
fi

if [ -z "$WALLPAPER" ] || [ ! -f "$WALLPAPER" ]; then
  mapfile -t FILES < <(find "$WALLPAPERS_DIR" -maxdepth 1 -type f \
    \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) | sort)
  [ "${#FILES[@]}" -eq 0 ] && exit 0
  WALLPAPER="${FILES[0]}"
fi

if ! pgrep -x awww-daemon >/dev/null 2>&1; then
  nohup awww-daemon >/dev/null 2>&1 &
  sleep 0.2
fi

awww img "$WALLPAPER" \
  --transition-type grow \
  --transition-duration 1 \
  --transition-fps 60 \
  >/dev/null 2>&1
