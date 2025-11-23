#!/usr/bin/env bash

# Exit on Error
set -e

KMDOT_CONFIG_DIR="$HOME/.config/kmdot"

if [ ! -f $KMDOT_CONFIG_DIR ]; then
  # Copy all the confings
  mkdir "$KMDOT_CONFIG_DIR"
  cp -r ./config/* "$KMDOT_CONFIG_DIR"

  # Copy all themes
  mkdir "$KMDOT_CONFIG_DIR/themes"
  cp -r ./themes/* "$KMDOT_CONFIG_DIR/themes"

  # Sync all configs locally with default settings
  ./sync/nvim.sh
  ./sync/rofi.sh
  # ./sync/wezterm.sh
  ./sync/starship.sh
  ./sync/ghostty.sh
  ./sync/hyprland.sh
  ./sync/waybar.sh

fi


