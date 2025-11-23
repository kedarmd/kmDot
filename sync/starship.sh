#!/usr/bin/env bash
set -e

STARSHIP_CONFIG_FILE="$HOME/.config/starship.toml"
KMDOT_STARSHIP_CONFIG_DIR="$HOME/.config/kmdot/starship"
KMDOT_STARSHIP_CONFIG_FILE="$KMDOT_STARSHIP_CONFIG_DIR/starship.toml"

if [ ! -e "$STARSHIP_CONFIG_FILE" ]; then
  echo "No starship config available. Adding kmDot starship config"
  ln -sf "$KMDOT_STARSHIP_CONFIG_FILE" "$STARSHIP_CONFIG_FILE"
  exit 0
fi

echo "INFO: STARSHIP config already exists"

# Check if it's a symlink
if [ ! -L "$STARSHIP_CONFIG_FILE" ]; then
   echo "WARNING: Starship config exists but is not a symlink. Reconfiguring..."
   rm -f "$STARSHIP_CONFIG_FILE"
   ln -sf "$KMDOT_STARSHIP_CONFIG_FILE" "$STARSHIP_CONFIG_FILE"
   echo "kmDot starship config synced!!!"
   exit 0
fi

STARSHIP_SOURCE=$(readlink "$STARSHIP_CONFIG_FILE")
if [ "$STARSHIP_SOURCE" != "$KMDOT_STARSHIP_CONFIG_FILE" ]; then
   echo "WARNING: Current symlink doesn't point to kmDot starship. Reconfiguring..."
   rm -f "$STARSHIP_CONFIG_FILE"
   ln -sf "$KMDOT_STARSHIP_CONFIG_FILE" "$STARSHIP_CONFIG_FILE"
   echo "kmDot starship config synced!!!"
   exit 0
fi


