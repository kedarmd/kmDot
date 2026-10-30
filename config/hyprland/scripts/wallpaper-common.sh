#!/usr/bin/env bash
#
# Shared wallpaper plumbing for apply_wallpaper.sh and cycle_wallpapers.sh.
# Sourced, never executed directly.
#
# Wallpapers live in themes/<theme>/wallpapers/ and are named
# <theme>-NN.<ext> with NN zero-padded to two digits. The number defines the
# cycle order, so Super+Ctrl+SPACE walks 01 -> 02 -> ... -> NN -> 01 and a
# theme switch always lands on 01. Version sort (sort -V) keeps the numeric
# order correct even if an unpadded name ever slips in.

THEMES_DIR="$HOME/.config/kmdot/themes"
CACHE_THEME_FILE="$HOME/.cache/kmdot_theme"

# Cycle position per theme (integer index) and the wallpaper currently painted
# (absolute path). Both are theme-scoped so switching themes never clobbers
# another theme's state.
wp_index_cache() { printf '%s\n' "$HOME/.cache/kmdot_wallpaper_index_${THEME:-default}"; }
wp_path_cache()  { printf '%s\n' "$HOME/.cache/kmdot_wallpaper_${THEME:-default}"; }

# One-time migration off the pre-awww (hyprpaper-era) cache names.
wp_migrate_cache() {
  local current="$1" legacy="$2"
  [ -f "$current" ] || [ ! -f "$legacy" ] || mv "$legacy" "$current"
}

# Active theme: explicit argument > ~/.cache/kmdot_theme > first installed theme.
wp_resolve_theme() {
  THEME="${1:-$(cat "$CACHE_THEME_FILE" 2>/dev/null)}"

  if [ -z "$THEME" ] && [ -d "$THEMES_DIR" ]; then
    THEME="$(ls -1 "$THEMES_DIR" 2>/dev/null | head -n 1)"
  fi
}

# The theme's wallpaper dir, falling back to ~/Pictures for a theme that ships
# no wallpapers of its own.
wp_resolve_dir() {
  WALLPAPERS_DIR="$THEMES_DIR/$THEME/wallpapers"
  [ -d "$WALLPAPERS_DIR" ] || WALLPAPERS_DIR="$HOME/Pictures"
}

# Fill FILES with the cycle-ordered wallpaper list.
wp_list() {
  local -a matches=(-iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp')

  FILES=()
  mapfile -t FILES < <(find "$WALLPAPERS_DIR" -maxdepth 1 -type f "${matches[@]}" \
    | LC_ALL=C sort -V)
}

# Paint via awww, then mirror onto the SDDM / session-lock wallpaper.
wp_paint() {
  local wallpaper="$1"

  [ -n "$wallpaper" ] && [ -f "$wallpaper" ] || return 0

  if ! pgrep -x awww-daemon >/dev/null 2>&1; then
    nohup awww-daemon >/dev/null 2>&1 &
    sleep 0.2
  fi

  if ! awww img "$wallpaper" \
    --transition-type grow \
    --transition-duration 1 \
    --transition-fps 60 \
    >/dev/null; then
    return 1
  fi

  # Best effort: the lockscreen reads this copy, but a failure here (read-only
  # root-owned file, full /var/tmp) must not fail the wallpaper switch.
  install -m 644 "$wallpaper" /var/tmp/kmdot-current.png 2>/dev/null || true
}
