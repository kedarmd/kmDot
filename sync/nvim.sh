#!/usr/bin/env bash
set -e

NVIM_CONFIG_DIR="$HOME/.config/nvim"
KMDOT_NVIM_CONFIG_DIR="$HOME/.config/kmdot/nvim"

if [ ! -e "$NVIM_CONFIG_DIR" ]; then
  echo "No nvim config available. Adding kmDot nvim config"
  ln -sf "$KMDOT_NVIM_CONFIG_DIR" "$NVIM_CONFIG_DIR"
  exit 0
fi

echo "INFO: NVIM config already exists"

# Check if it's a symlink
if [ ! -L "$NVIM_CONFIG_DIR" ]; then
  echo "WARNING: Nvim config exists but is not a symlink. Reconfiguring..."
  rm -rf "$NVIM_CONFIG_DIR"
  ln -s "$KMDOT_NVIM_CONFIG_DIR" "$NVIM_CONFIG_DIR"
  echo "kmDot nvim config synced!!!"
  exit 0
fi

NVIM_SOURCE=$(readlink "$NVIM_CONFIG_DIR")
if [ "$NVIM_SOURCE" != "$KMDOT_NVIM_CONFIG_DIR" ]; then
   echo "WARNING: Current symlink doesn't point to kmDot nvim. Reconfiguring..."
   rm -f "$NVIM_CONFIG_DIR"
   ln -sf "$KMDOT_NVIM_CONFIG_DIR" "$NVIM_CONFIG_DIR"
   echo "kmDot nvim config synced!!!"
   exit 0
fi

