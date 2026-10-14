#!/usr/bin/env bash

# Exit on Error
set -e

THEME="$1"
THEMES_DIR="$HOME/.config/kmdot/themes"
WALLPAPERS_SOURCE="$THEMES_DIR/$THEME/wallpapers"
CACHE_THEME_FILE="$HOME/.cache/kmdot_theme"

# Check if theme exists
if [ ! -d "$WALLPAPERS_SOURCE" ]; then
  echo "ERROR: Wallpapers for theme '$THEME' do not exist at $WALLPAPERS_SOURCE"
  exit 1
fi

# Record active theme for wallpaper persistence
mkdir -p "$(dirname "$CACHE_THEME_FILE")"
echo "$THEME" > "$CACHE_THEME_FILE"

# Apply new wallpaper on theme change, but only inside a live Hyprland
# session — headless runs have no compositor/awww to paint through.
# The cache file above is already written, so the wallpaper resolves
# on next login regardless.
#
# --first resets the cycle rather than advancing it, so switching to a theme
# always lands on that theme's wallpaper 01 instead of resuming wherever the
# last visit to it stopped.
if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
  ~/.config/kmdot/hyprland/scripts/cycle_wallpapers.sh "$THEME" --first
else
  echo "(hyprland not running — wallpaper applies on next login)" >&2
fi

echo "Wallpapers updated successfully!"
