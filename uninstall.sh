#!/usr/bin/env bash

set -e

echo '
██╗                   ██████╗              ██╗     
██║                   ██╔══██╗             ██║     
██║ ██╗ ████████████╗ ██║  ██║  ██████╗  ██████╗ 
█████╔╝ ██╔══██╔══██║ ██║  ██║ ██╔═══██╗ ╚═██╔═╝ 
██╔═██╗ ██║  ██║  ██║ ██████╔╝ ╚██████╔╝   ╚████╗
╚═╝ ╚═╝ ╚═╝  ╚═╝  ╚═╝ ╚═════╝   ╚═════╝     ╚═══╝
'

echo "Welcome to kmDot uninstaller!"
echo ""

APPS=(
  "ghostty"
  "hyprland"
  "nvim"
  "rofi"
  "starship"
  "waybar"
)

declare -A TARGETS
TARGETS["ghostty"]="$HOME/.config/ghostty"
TARGETS["hyprland"]="$HOME/.config/hypr"
TARGETS["nvim"]="$HOME/.config/nvim"
TARGETS["rofi"]="$HOME/.config/rofi"
TARGETS["starship"]="$HOME/.config/starship.toml"
TARGETS["waybar"]="$HOME/.config/waybar"

declare -A SOURCES
SOURCES["ghostty"]="$HOME/.config/kmdot/ghostty"
SOURCES["hyprland"]="$HOME/.config/kmdot/hyprland"
SOURCES["nvim"]="$HOME/.config/kmdot/nvim"
SOURCES["rofi"]="$HOME/.config/kmdot/rofi"
SOURCES["waybar"]="$HOME/.config/kmdot/waybar"

echo "Available apps to uninstall:"
echo ""
for i in "${!APPS[@]}"; do
  echo "  $((i+1))) ${APPS[$i]}"
done
echo ""
echo "Enter numbers separated by space (e.g., 1 3 5) or 'all' for everything: "
read -r selection

if [ "$selection" = "all" ]; then
  SELECTED=("${APPS[@]}")
else
  SELECTED=()
  for num in $selection; do
    idx=$((num-1))
    if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#APPS[@]}" ]; then
      SELECTED+=("${APPS[$idx]}")
    fi
  done
fi

if [ ${#SELECTED[@]} -eq 0 ]; then
  echo "No apps selected. Exiting."
  exit 0
fi

echo ""
echo "Uninstalling: ${SELECTED[*]}"
echo ""

for app in "${SELECTED[@]}"; do
  echo "Uninstalling $app..."
  target="${TARGETS[$app]}"
  source="${SOURCES[$app]}"
  
  if [ -n "$target" ]; then
    rm -rf "$target"
  fi
  if [ -n "$source" ]; then
    rm -rf "$source"
  fi
done

echo ""
echo "Uninstall complete! 🎉"
