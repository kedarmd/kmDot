#!/usr/bin/env bash
set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SDDM_THEME_DIR="/usr/share/sddm/themes/kmd-hyprlock"
SDDM_WALLPAPER="/usr/share/backgrounds/kmdot-ign_astronaut.png"
REPO_WALLPAPER="$REPO_DIR/themes/nord/wallpapers/ign_astronaut.png"

sudo rm -rf "$SDDM_THEME_DIR"
sudo mkdir -p "$SDDM_THEME_DIR"
sudo install -Dm644 "$REPO_DIR/config/sddm/themes/kmd-hyprlock/theme.conf" "$SDDM_THEME_DIR/theme.conf"
sudo install -Dm644 "$REPO_DIR/config/sddm/themes/kmd-hyprlock/Main.qml" "$SDDM_THEME_DIR/Main.qml"
sudo install -Dm644 "$REPO_DIR/config/sddm/themes/kmd-hyprlock/metadata.desktop" "$SDDM_THEME_DIR/metadata.desktop"
sudo install -Dm644 "$REPO_WALLPAPER" "$SDDM_WALLPAPER"

echo "kmDot sddm theme synced!!!"
