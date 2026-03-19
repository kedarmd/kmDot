#!/usr/bin/env bash

set -e

if ! command -v gum &>/dev/null; then
  echo "Error: gum is not installed."
  echo ""
  echo "Install it with:"
  echo "  sudo pacman -S gum"
  echo ""
  echo "Or visit: https://github.com/charmbracelet/gum"
  exit 1
fi

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

echo "Select apps to uninstall:"
echo ""

SELECTED=()
while IFS= read -r app; do
  [ -n "$app" ] && SELECTED+=("$app")
done < <(
  gum choose \
    --header="Select apps to uninstall:" \
    --unselected-prefix="[ ] " \
    --selected-prefix="[x] " \
    --no-limit \
    --height=12 \
    "${APPS[@]}"
)

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
