#!/usr/bin/env bash

# Exit on Error
set -e

THEME="$1"
THEMES_DIR="$HOME/.config/kmdot/themes"
WALLPAPERS_SOURCE="$THEMES_DIR/$THEME/wallpapers"
WALLPAPERS_DEST="$HOME/Pictures"

# Check if theme exists
if [ ! -d "$WALLPAPERS_SOURCE" ]; then
  echo "ERROR: Wallpapers for theme '$THEME' do not exist at $WALLPAPERS_SOURCE"
  exit 1
fi

# Create Pictures directory if it doesn't exist
mkdir -p "$WALLPAPERS_DEST"

# Clear existing wallpapers from Pictures folder
echo "Clearing existing wallpapers from $WALLPAPERS_DEST..."
find "$WALLPAPERS_DEST" -maxdepth 1 -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.bmp" -o -iname "*.gif" -o -iname "*.webp" \) -delete

# Copy new wallpapers from theme folder
echo "Copying wallpapers for theme '$THEME'..."
cp -v "$WALLPAPERS_SOURCE"/* "$WALLPAPERS_DEST/" 2>/dev/null || true

echo "Wallpapers updated successfully!"
