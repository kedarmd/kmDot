#!/usr/bin/env bash

WALLPAPERS_DIR="$HOME/Pictures"
CACHE_FILE="$HOME/.cache/hyprpaper_wallpaper_index"

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

# Get all monitor names
MONITORS=$(hyprctl monitors -j | jq -r '.[].name')

# Reset and apply wallpaper via hyprpaper
hyprctl hyprpaper unload all > /dev/null 2>&1
hyprctl hyprpaper preload "$WALLPAPER"

for MON in $MONITORS; do
  hyprctl hyprpaper wallpaper "$MON,$WALLPAPER"
done

