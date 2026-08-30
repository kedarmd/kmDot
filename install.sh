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

# --- Bootstrap: Node.js (required for quickshell launchers, calendar, Handy) ---

if ! command -v node &>/dev/null; then
  echo ""
  echo "Node.js is required for kmDot (launcher toggle, calendar, Handy)."

  if command -v mise &>/dev/null; then
    echo "mise found — installing Node.js 24 via mise..."
    mise install nodejs@24
    echo "Node.js installed."
  else
    echo ""
    echo "Node.js not found and mise is not installed."
    echo "Install Node.js with your preferred method:"
    echo ""
    echo "  Recommended: mise (manages multiple Node versions)"
    echo "    sudo pacman -S mise"
    echo "    mise install nodejs@24"
    echo ""
    echo "  Alternatives:"
    echo "    nvm:     nvm install 24"
    echo "    fnm:     fnm install 24"
    echo "    volta:   volta install node@24"
    echo "    pacman:  sudo pacman -S nodejs-lts-jod"
    echo ""
    echo "After installing, re-run: ./install.sh"
    exit 1
  fi
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
PKGS["runtime"]="ttf-jetbrains-mono-nerd networkmanager network-manager-applet pipewire wireplumber pipewire-pulse bluez blueman wl-clipboard brightnessctl upower jq playerctl curl"

# Canonical order for display
APPS=(
  "battery"
  "fish"
  "ghostty"
  "herdr"
  "hyprland"
  "nvim"
  "quickshell"
  "runtime"
  "sddm"
  "starship"
  "theme-switcher"
  "tmux"
  "xdg-desktop-portal"
)

# --- Mode selection ---
# Usage: ./install.sh          (interactive gum choose)
#        ./install.sh --all    (non-interactive, install everything)

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
    # Prefer pacman for official repos, fall back to yay for AUR
    if pacman -Si "$pkg" &>/dev/null; then
      if err=$(sudo pacman -S --noconfirm --needed "$pkg" 2>&1); then
        echo "done."
      else
        echo "FAILED"
        echo "    $err" | head -5
      fi
    else
      if err=$(yay -S --noconfirm --needed "$pkg" 2>&1); then
        echo "done."
      else
        echo "FAILED"
        echo "    $err" | head -5
      fi
    fi
  done
done

echo ""
echo "All done!"
echo ""
echo "Next step: run ./config-install.sh to deploy config files."
