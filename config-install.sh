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

for arg in "$@"; do
  case "$arg" in
    --all) MODE="all" ;;
    -h|--help)
      echo "Usage: ./config-install.sh [--all]"
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      echo "Usage: ./config-install.sh [--all]" >&2
      exit 2
      ;;
  esac
done

if [[ "$MODE" == "all" ]]; then
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

FAILED_APPS=()
for app in "${SELECTED[@]}"; do
  echo "Installing $app..."
  if "$REPO_DIR/sync/$app.sh"; then
    :
  else
    echo "WARNING: $app failed (continuing with remaining apps)" >&2
    FAILED_APPS+=("$app")
  fi
done

if [[ "$MODE" == "all" && ! -f "$HOME/.cache/kmdot_theme" ]]; then
  # Fresh box only: a re-run on an existing machine must not clobber the
  # active theme. The cache file is written by every theme apply, so its
  # absence reliably means "never themed".
  echo ""
  echo "Applying default theme: $DEFAULT_THEME..."
  "$REPO_DIR/theme-switcher/main.sh" "$DEFAULT_THEME"
fi

echo ""
if [ ${#FAILED_APPS[@]} -gt 0 ]; then
  echo "Failed apps: ${FAILED_APPS[*]}" >&2
  echo "Fix the failures above, then re-run ./config-install.sh (or ./sync/<app>.sh per app)."
  exit 1
fi
echo "All done!"
