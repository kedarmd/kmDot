#!/usr/bin/env bash
set -e

WEZTERM_CONFIG_DIR="$HOME/.config/wezterm"
KMDOT_WEZTERM_CONFIG_DIR="$HOME/.config/kmdot/wezterm"

if [ ! -e "$WEZTERM_CONFIG_DIR" ]; then
  echo "No wezterm config available. Adding kmDot wezterm config"
  git clone https://github.com/kedarmd/nvim-wez-navigator.git "$HOME/.config/kmdot/wezterm/plugins/nvim-wez-navigator"
  ln -sf "$KMDOT_WEZTERM_CONFIG_DIR" "$WEZTERM_CONFIG_DIR"
  ln -sf "$KMDOT_WEZTERM_CONFIG_DIR/wezterm.lua" "$HOME/.wezterm.lua"
  exit 0
fi

echo "INFO: WEZTERM config already exists"

WEZTERM_SOURCE=$(readlink "$WEZTERM_CONFIG_DIR")
if [ "$WEZTERM_SOURCE" != "$KMDOT_WEZTERM_CONFIG_DIR" ]; then
   echo "WARNING: Current symlink doesn't point to kmDot wezterm. Reconfiguring..."
   rm -f "$WEZTERM_CONFIG_DIR"
   git clone https://github.com/kedarmd/nvim-wez-navigator.git "$HOME/.config/kmdot/wezterm/plugins/nvim-wez-navigator"
   ln -sf "$KMDOT_WEZTERM_CONFIG_DIR" "$WEZTERM_CONFIG_DIR"
   ln -sf "$KMDOT_WEZTERM_CONFIG_DIR/wezterm.lua" "$HOME/.wezterm.lua"
   echo "kmDot wezterm config synced!!!"
   exit 0
fi

