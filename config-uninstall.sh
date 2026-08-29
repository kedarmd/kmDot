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

echo "Welcome to kmDot config uninstaller!"
echo ""

# sddm is intentionally absent: sync/sddm.sh installs into system paths
# (/usr/share/sddm/themes, /usr/share/backgrounds) which only root can remove.
# These apps are excluded from config-uninstall.sh.
APPS=(
  "battery"
  "fish"
  "ghostty"
  "herdr"
  "hyprland"
  "nvim"
  "quickshell"
  "starship"
  "theme-switcher"
  "tmux"
  "xdg-desktop-portal"
)

declare -A TARGETS
TARGETS["battery"]="$HOME/.config/systemd/user/battery-monitor.service $HOME/.config/systemd/user/battery-monitor.timer"
TARGETS["fish"]="$HOME/.config/fish"
TARGETS["ghostty"]="$HOME/.config/ghostty"
TARGETS["herdr"]="$HOME/.config/herdr"
TARGETS["hyprland"]="$HOME/.config/hypr"
TARGETS["nvim"]="$HOME/.config/nvim"
TARGETS["quickshell"]="$HOME/.config/quickshell"
TARGETS["starship"]="$HOME/.config/starship.toml"
TARGETS["theme-switcher"]="$HOME/.config/kmdot/theme-switcher $HOME/.config/kmdot/themes"
TARGETS["tmux"]="$HOME/.config/tmux $HOME/.tmux.conf"
TARGETS["xdg-desktop-portal"]="$HOME/.config/xdg-desktop-portal"

declare -A SOURCES
SOURCES["fish"]="$HOME/.config/kmdot/fish"
SOURCES["ghostty"]="$HOME/.config/kmdot/ghostty"
SOURCES["herdr"]="$HOME/.config/kmdot/herdr"
SOURCES["hyprland"]="$HOME/.config/kmdot/hyprland"
SOURCES["nvim"]="$HOME/.config/kmdot/nvim"
SOURCES["quickshell"]="$HOME/.config/kmdot/quickshell"
SOURCES["tmux"]="$HOME/.config/kmdot/tmux"
SOURCES["xdg-desktop-portal"]="$HOME/.config/kmdot/xdg-desktop-portal"

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
    --height=$(( ${#APPS[@]} + 2 )) \
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
  target="${TARGETS[$app]:-}"
  source="${SOURCES[$app]:-}"

  # TARGETS/SOURCES may hold space-separated path lists (e.g. tmux links both
  # ~/.config/tmux and ~/.tmux.conf); word splitting is intentional — managed
  # paths never contain spaces.
  for p in $target; do
    rm -rf "$p"
  done
  for p in $source; do
    rm -rf "$p"
  done
done

echo ""
echo "Uninstall complete! 🎉"
