#!/usr/bin/env bash

# Exit on Error
set -e

CONFIG_FILE="$HOME/.config/kmdot/hyprland/theme.conf"
THEME="$1"
THEME_FILE="$HOME/.config/kmdot/themes/$THEME/hyprland.conf"
HYPRLOCK_TEMPLATE_FILE="$HOME/.config/kmdot/hyprland/hyprlock.base.conf"
HYPRLOCK_CONFIG_FILE="$HOME/.config/kmdot/hyprland/hyprlock.conf"
HYPRLOCK_THEME_FILE="$HOME/.config/kmdot/themes/$THEME/hyprlock.conf"

# Check if theme file exists
if [ ! -f "$THEME_FILE" ]; then
  echo "ERROR: Theme '$THEME' does not exist for hyprland."
  exit 1
fi

if [ ! -f "$HYPRLOCK_THEME_FILE" ]; then
  echo "ERROR: Theme '$THEME' does not exist for hyprlock."
  exit 1
fi

if [ ! -f "$HYPRLOCK_TEMPLATE_FILE" ]; then
  echo "ERROR: Hyprlock template file does not exist."
  exit 1
fi

cat "$THEME_FILE" > "$CONFIG_FILE"

# shellcheck source=/dev/null
. "$HYPRLOCK_THEME_FILE"

sed \
  -e "s|@HYPRLOCK_BG@|$HYPRLOCK_BG|g" \
  -e "s|@HYPRLOCK_INNER@|$HYPRLOCK_INNER|g" \
  -e "s|@HYPRLOCK_OUTER@|$HYPRLOCK_OUTER|g" \
  -e "s|@HYPRLOCK_FONT@|$HYPRLOCK_FONT|g" \
  -e "s|@HYPRLOCK_LABEL@|$HYPRLOCK_LABEL|g" \
  "$HYPRLOCK_TEMPLATE_FILE" > "$HYPRLOCK_CONFIG_FILE"

hyprctl reload

echo "✓ Hyprland theme updated to: $THEME"
