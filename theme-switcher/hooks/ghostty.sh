#!/usr/bin/env bash

# Exit on Error
set -e

CONFIG_FILE="$HOME/.config/ghostty/config"
THEME="$1"
COLORSCHEME_FILE="$HOME/.config/kmdot/themes/$THEME/ghostty.conf"

# Check if theme file exists
if [ ! -f "$COLORSCHEME_FILE" ]; then
  echo "ERROR: Theme '$THEME' does not exist for ghostty."
  exit 1
fi

# Read the theme value from the colorscheme file
THEME_VALUE=$(grep "^theme = " "$COLORSCHEME_FILE" | head -1 | sed 's/^theme = //' | tr -d '"')

# Update the config file with the new theme
if grep -q "^theme = " "$CONFIG_FILE"; then
  sed -i "s/^theme = .*/theme = \"$THEME_VALUE\"/" "$CONFIG_FILE"
else
  sed -i "1i theme = \"$THEME_VALUE\"" "$CONFIG_FILE"
fi

echo "✓ Ghostty theme updated to: $THEME_VALUE"
