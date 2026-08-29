#!/usr/bin/env bash

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

echo '
██╗                   ██████╗              ██╗
██║                   ██╔══██╗             ██║
██║ ██╗ ████████████╗ ██║  ██║  ██████╗  ██████╗
█████╔╝ ██╔══██╔══██║ ██║  ██║ ██╔═══██╗ ╚═██╔═╝
██╔═██╗ ██║  ██║  ██║ ██████╔╝ ╚██████╔╝   ╚████╗
╚═╝ ╚═╝ ╚═╝  ╚═╝  ╚═╝ ╚═════╝   ╚═════╝     ╚═══╝
'

echo "kmDot package installer"
echo ""

# --- Bootstrap: yay (AUR helper) ---

install_yay() {
  if command -v yay &>/dev/null; then
    echo "yay is already installed."
    return
  fi

  echo "Installing yay from AUR..."
  local tmpdir
  tmpdir=$(mktemp -d)
  git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"
  (cd "$tmpdir/yay" && makepkg -si --noconfirm)
  rm -rf "$tmpdir"
  echo "yay installed."
}

install_yay

# --- Bootstrap: gum (needed by config scripts) ---

if ! command -v gum &>/dev/null; then
  echo "Installing gum..."
  sudo pacman -S --noconfirm --needed gum
  echo "gum installed."
fi

# --- Package mapping ---
# Key = config directory name (matches sync/<name>.sh)
# Value = pacman/yay package name(s), space-separated for multi-package entries
# Empty value = config-only, skip with a note

declare -A PKGS
PKGS["fish"]="fish"
PKGS["ghostty"]="ghostty"
PKGS["herdr"]="herdr-bin"
PKGS["hyprland"]="hyprland hypridle hyprlock hyprpaper"
PKGS["nvim"]="neovim"
PKGS["quickshell"]="quickshell"
PKGS["sddm"]="sddm"
PKGS["starship"]="starship"
PKGS["tmux"]="tmux"
PKGS["xdg-desktop-portal"]="xdg-desktop-portal xdg-desktop-portal-hyprland"
PKGS["battery"]=""
PKGS["theme-switcher"]=""
PKGS["gtk"]=""
PKGS["qt"]=""
PKGS["polkit"]=""
PKGS["gum"]="gum"

# Canonical order for display
APPS=(
  "battery"
  "fish"
  "ghostty"
  "gum"
  "gtk"
  "herdr"
  "hyprland"
  "nvim"
  "polkit"
  "qt"
  "quickshell"
  "sddm"
  "starship"
  "theme-switcher"
  "tmux"
  "xdg-desktop-portal"
)

# --- Mode selection ---

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
      --header="Select apps to install packages for:" \
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
echo "Installing packages for: ${SELECTED[*]}"
echo ""

# --- Install packages ---

for app in "${SELECTED[@]}"; do
  pkgs="${PKGS[$app]:-}"

  if [ -z "$pkgs" ]; then
    echo "  $app: config-only, no package to install."
    continue
  fi

  for pkg in $pkgs; do
    if pacman -Qi "$pkg" &>/dev/null; then
      echo "  $pkg: already installed."
      continue
    fi

    echo -n "  Installing $pkg... "
    if yay -S --noconfirm --needed "$pkg" 2>/dev/null; then
      echo "done."
    else
      echo "FAILED"
    fi
  done
done

echo ""
echo "All done!"
echo ""
echo "Next step: run ./config-install.sh to deploy config files."
