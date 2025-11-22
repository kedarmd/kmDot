#!/usr/bin/env bash
set -e

ROFI_CONFIG_DIR="$HOME/.config/rofi"
KMDOT_ROFI_CONFIG_DIR="$HOME/.config/kmdot/rofi"

if [ ! -e "$ROFI_CONFIG_DIR" ]; then
  echo "No rofi config available. Adding kmDot rofi config"
  ln -sf "$KMDOT_ROFI_CONFIG_DIR" "$ROFI_CONFIG_DIR"
  exit 0
fi

echo "INFO: ROFI config already exists"

ROFI_SOURCE=$(readlink "$ROFI_CONFIG_DIR")
if [ "$ROFI_SOURCE" != "$KMDOT_ROFI_CONFIG_DIR" ]; then
   echo "WARNING: Current symlink doesn't point to kmDot rofi. Reconfiguring..."
   rm -f "$ROFI_CONFIG_DIR"
   ln -sf "$KMDOT_ROFI_CONFIG_DIR" "$ROFI_CONFIG_DIR"
   echo "kmDot rofi config synced!!!"
   exit 0
fi

