#!/usr/bin/env bash

THEMES_DIR="$HOME/.config/kmdot/themes"
CACHE_THEME_FILE="$HOME/.cache/kmdot_theme"
THEME="${1:-$(cat "$CACHE_THEME_FILE" 2>/dev/null)}"

if [ -z "$THEME" ] && [ -d "$THEMES_DIR" ]; then
  THEME="$(ls -1 "$THEMES_DIR" 2>/dev/null | head -n 1)"
fi

sync_hyprlock() {
  local wallpaper_path="$1"
  local hyprlock_template="$HOME/.config/kmdot/hyprland/hyprlock.base.conf"
  local hyprlock_config="$HOME/.config/kmdot/hyprland/hyprlock.conf"

  [ -f "$hyprlock_template" ] || return 0

  if [ -n "$wallpaper_path" ] && [ -f "$wallpaper_path" ]; then
    sed "s|^\s*path\s*=.*|  path = $wallpaper_path|" "$hyprlock_template" > "$hyprlock_config"
  else
    cp "$hyprlock_template" "$hyprlock_config"
  fi

  if pgrep -x hyprlock >/dev/null 2>&1; then
    pkill -USR1 hyprlock
  fi
}

sync_sddm() {
  local wallpaper_path="$1"
  local sddm_wallpaper="/var/tmp/kmdot-current.png"

  if [ -n "$wallpaper_path" ] && [ -f "$wallpaper_path" ]; then
    install -m 644 "$wallpaper_path" "$sddm_wallpaper"
  fi
}

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

sync_hyprlock "$WALLPAPER"
sync_sddm "$WALLPAPER"
