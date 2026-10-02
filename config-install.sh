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

# theme-switcher first: it deploys themes/ + hooks that the themed apps depend on.
APPS=(
  "theme-switcher"
  "battery"
  "fish"
  "ghostty"
  "herdr"
  "hyprland"
  "nvim"
  "quickshell"
  "sddm"
  "starship"
  "tmux"
  "xdg-desktop-portal"
  "system"
)

DEFAULT_THEME="tokyonight"

# --- Mode selection ---
# Usage: ./config-install.sh        (interactive gum choose)
#        ./config-install.sh --all  (non-interactive, install everything + default theme)

MODE="interactive"
SELECTED=()

if [[ "${1:-}" == "--all" ]]; then
  MODE="all"
  SELECTED=("${APPS[@]}")
fi

if [[ "$MODE" == "interactive" ]]; then
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

if [[ "$MODE" == "all" ]]; then
  echo ""
  echo "Applying default theme: $DEFAULT_THEME..."
  "$REPO_DIR/theme-switcher/main.sh" "$DEFAULT_THEME"
fi

echo ""
echo "All done!"
