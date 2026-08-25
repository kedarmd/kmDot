#!/usr/bin/env bash

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
KMDOT_CONFIG_DIR="$HOME/.config/kmdot"

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

echo "Welcome to kmDot installer!"
echo ""

APPS=(
  "battery"
  "fish"
  "ghostty"
  "herdr"
  "hyprland"
  "nvim"
  "quickshell"
  "starship"
  "swaync"
  "theme-switcher"
  "tmux"
  "xdg-desktop-portal"
)

SELECTED=()
while IFS= read -r app; do
  [ -n "$app" ] && SELECTED+=("$app")
done < <(
  gum choose \
    --header="Select apps to install:" \
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
echo "Installing: ${SELECTED[*]}"
echo ""

for app in "${SELECTED[@]}"; do
  echo "Installing $app..."
  "$REPO_DIR/sync/$app.sh"
done

echo ""
echo "All done!"
