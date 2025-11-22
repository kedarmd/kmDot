#!/usr/bin/env bash

# Exit on Error
set -e

KMDOT_CONFIG_DIR="$HOME/.config/kmdot"

if [ ! -f $KMDOT_CONFIG_DIR ]; then
  mkdir "$KMDOT_CONFIG_DIR"
  cp -r ./config/* "$KMDOT_CONFIG_DIR"
  # Sync all configs locally with default settings
  ./sync/nvim.sh
  ./sync/rofi.sh
  ./sync/wezterm.sh
  ./sync/starship.sh

  # Copy all themes
  mkdir "$KMDOT_CONFIG_DIR/themes"
  cp -r ./themes/* "$KMDOT_CONFIG_DIR/themes"
fi


