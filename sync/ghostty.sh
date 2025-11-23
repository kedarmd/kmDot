#!/usr/bin/env bash
set -e

GHOSTTY_CONFIG_DIR="$HOME/.config/ghostty"
KMDOT_GHOSTTY_CONFIG_DIR="$HOME/.config/kmdot/ghostty"

if [ ! -e "$GHOSTTY_CONFIG_DIR" ]; then
  echo "No ghostty config available. Adding kmDot ghostty config"
  ln -sf "$KMDOT_GHOSTTY_CONFIG_DIR" "$GHOSTTY_CONFIG_DIR"
  exit 0
fi

echo "INFO: GHOSTTY config already exists"

# Check if it's a symlink
if [ ! -L "$GHOSTTY_CONFIG_DIR" ]; then
  echo "WARNING: Ghostty config exists but is not a symlink. Reconfiguring..."
  rm -rf "$GHOSTTY_CONFIG_DIR"
  ln -s "$KMDOT_GHOSTTY_CONFIG_DIR" "$GHOSTTY_CONFIG_DIR"
  echo "kmDot ghostty config synced!!!"
  exit 0
fi

GHOSTTY_SOURCE=$(readlink "$GHOSTTY_CONFIG_DIR")
if [ "$GHOSTTY_SOURCE" != "$KMDOT_GHOSTTY_CONFIG_DIR" ]; then
   echo "WARNING: Current symlink doesn't point to kmDot ghostty. Reconfiguring..."
   rm -f "$GHOSTTY_CONFIG_DIR"
   ln -sf "$KMDOT_GHOSTTY_CONFIG_DIR" "$GHOSTTY_CONFIG_DIR"
   echo "kmDot ghostty config synced!!!"
   exit 0
fi

