#!/usr/bin/env bash

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

if ! command -v gum &>/dev/null; then
  echo "Installing gum..."
  sudo pacman -S --noconfirm --needed gum
  echo "gum installed."
fi

echo '
██╗                   ██████╗              ██╗     
██║                   ██╔══██╗             ██║     
██║ ██╗ ████████████╗ ██║  ██║  ██████╗  ██████╗ 
█████╔╝ ██╔══██╔══██║ ██║  ██║ ██╔═══██╗ ╚═██╔═╝ 
██╔═██╗ ██║  ██║  ██║ ██████╔╝ ╚██████╔╝   ╚████╗
╚═╝ ╚═╝ ╚═╝  ╚═╝  ╚═╝ ╚═════╝   ╚═════╝     ╚═══╝
'

echo "Welcome to kmDot config installer!"
echo ""

APPS=(
  "battery"
  "fish"
  "ghostty"
  "herdr"
  "hyprland"
  "nvim"
  "quickshell"
  "sddm"
  "starship"
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
    --height=$(( ${#APPS[@]} + 2 )) \
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
