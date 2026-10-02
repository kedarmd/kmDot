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

# --- Bootstrap: git + base-devel (needed for yay below) ---

if ! command -v git &>/dev/null || ! command -v makepkg &>/dev/null; then
  echo "Installing git and base-devel..."
  sudo pacman -S --noconfirm --needed git base-devel
  echo "git and base-devel installed."
fi

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
    echo "mise not found — installing nodejs-lts-jod via pacman..."
    sudo pacman -S --noconfirm --needed nodejs-lts-jod
    echo "Node.js installed."
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
PKGS["hyprland"]="hyprland hypridle hyprlock hyprshot awww"
PKGS["nvim"]="neovim"
PKGS["quickshell"]="quickshell"
PKGS["sddm"]="sddm"
PKGS["starship"]="starship"
PKGS["tmux"]="tmux"
PKGS["xdg-desktop-portal"]="xdg-desktop-portal xdg-desktop-portal-hyprland"
PKGS["battery"]=""
PKGS["theme-switcher"]=""
PKGS["runtime"]="ttf-jetbrains-mono-nerd networkmanager network-manager-applet pipewire wireplumber pipewire-pulse bluez blueman wl-clipboard brightnessctl upower jq playerctl curl libnotify power-profiles-daemon lua gnome-keyring nautilus zen-browser"
# Opt-in groups: visible in the picker, excluded from --all
PKGS["themed-extras"]="btop zed opencode-bin"
PKGS["server"]="tailscale jellyfin docker containerd"
PKGS["handy"]="handy-bin"

# Canonical order for display (includes opt-in groups)
APPS=(
  "battery"
  "fish"
  "ghostty"
  "handy"
  "herdr"
  "hyprland"
  "nvim"
  "quickshell"
  "runtime"
  "sddm"
  "server"
  "starship"
  "theme-switcher"
  "themed-extras"
  "tmux"
  "xdg-desktop-portal"
)

# Default groups installed by --all (opt-in groups excluded)
DEFAULT_APPS=(
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
# Usage: ./install.sh                          (interactive gum choose over all groups)
#        ./install.sh --all                     (non-interactive, default groups only)
#        ./install.sh --all [--themed-extras] [--server] [--handy]
#                                               (defaults plus the given opt-in groups)
#        ./install.sh [--themed-extras] [--server] [--handy]
#                                               (non-interactive, just the given opt-in groups)

MODE="interactive"
SELECTED=()
OPT_INS=()

for arg in "$@"; do
  case "$arg" in
    --all) MODE="all" ;;
    --themed-extras|--server|--handy) OPT_INS+=("${arg#--}") ;;
    -h|--help)
      sed -n '/^# Usage:/,/^$/p' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      echo "Usage: ./install.sh [--all] [--themed-extras] [--server] [--handy]" >&2
      exit 2
      ;;
  esac
done

if [[ "$MODE" == "all" ]]; then
  SELECTED=("${DEFAULT_APPS[@]}" "${OPT_INS[@]}")
elif [ ${#OPT_INS[@]} -gt 0 ]; then
  MODE="opt-in"
  SELECTED=("${OPT_INS[@]}")
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
