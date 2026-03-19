#!/usr/bin/env bash

# Exit on errors and unset variables
set -euo pipefail

# Fix locale issues for rofi/xkbcommon
export LANG=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8

THEME_DIR="$HOME/.config/kmdot/themes"
THEME_SWITCHER="$HOME/.config/kmdot/theme-switcher/main.sh"

if [ ! -d "$THEME_DIR" ]; then
  notify-send "Theme Switcher" "Theme directory missing: $THEME_DIR"
  exit 1
fi

mapfile -t themes < <(find "$THEME_DIR" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | sort)

if [ ${#themes[@]} -eq 0 ]; then
  notify-send "Theme Switcher" "No themes found in $THEME_DIR"
  exit 1
fi

declare -A theme_icons=(
  [catppuccin]=
  [everforest]=
  [nord]=
  [onedark]=
  [tokyonight]=
)

DEFAULT_ICON=""
display_choices=()
declare -A theme_from_display=()

for theme in "${themes[@]}"; do
  icon="${theme_icons[$theme]:-$DEFAULT_ICON}"
  display="${icon}  ${theme}"
  display_choices+=("$display")
  theme_from_display["$display"]="$theme"
done

choice=$(printf '%s\n' "${display_choices[@]}" | rofi -dmenu -normal-window -i -p "Themes" -theme-str 'element-icon { width: 0px; padding: 0px; margin: 0px; } element-icon selected { width: 0px; padding: 0px; margin: 0px; }')

[ -z "$choice" ] && exit 0

theme="${theme_from_display[$choice]:-}"
[ -z "$theme" ] && exit 0

if [ ! -x "$THEME_SWITCHER" ]; then
  notify-send "Theme Switcher" "Main switcher script not executable: $THEME_SWITCHER"
  exit 1
fi

"$THEME_SWITCHER" "$theme"
