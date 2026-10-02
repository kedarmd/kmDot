#!/usr/bin/env bash

# Exit on Error
set -e

CONFIG_FILE="$HOME/.config/kmdot/hyprland/theme.lua"
THEME="$1"
THEME_FILE="$HOME/.config/kmdot/themes/$THEME/hyprland.lua"

# Check if theme file exists
if [ ! -f "$THEME_FILE" ]; then
  echo "ERROR: Theme '$THEME' does not exist for hyprland."
  exit 1
fi

cat "$THEME_FILE" > "$CONFIG_FILE"

# Reload only inside a live Hyprland session; headless runs (SSH, fresh
# --all before first login) have no compositor to signal. The file above
# is already written, so the theme applies on next login regardless.
if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && command -v hyprctl &>/dev/null; then
  hyprctl reload
else
  echo "(hyprland not running — theme applies on next login)" >&2
fi

echo "✓ Hyprland theme updated to: $THEME"
