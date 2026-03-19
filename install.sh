#!/usr/bin/env bash

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
KMDOT_CONFIG_DIR="$HOME/.config/kmdot"

echo '
██╗                   ██████╗              ██╗     
██║                   ██╔══██╗             ██║     
██║ ██╗ ████████████╗ ██║  ██║  ██████╗  ██████╗ 
█████╔╝ ██╔══██╔══██║ ██║  ██║ ██╔═══██╗ ╚═██╔═╝ 
██╔═██╗ ██║  ██║  ██║ ██████╔╝ ╚██████╔╝   ╚████╗
╚═╝ ╚═╝ ╚═╝  ╚═╝  ╚═╝ ╚═════╝   ╚═════╝     ╚═══╝
'

echo "Welcome to kmDot installer!"
echo ""

APPS=(
  "ghostty"
  "hyprland"
  "nvim"
  "rofi"
  "starship"
  "waybar"
)

echo "Available apps to install:"
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
echo "Installing: ${SELECTED[*]}"
echo ""

for app in "${SELECTED[@]}"; do
  echo "Installing $app..."
  "$REPO_DIR/sync/$app.sh"
done

echo ""
echo "All done! 🎉"


