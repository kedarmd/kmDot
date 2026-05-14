#!/usr/bin/env bash

set -e

CONFIG_FILE="$HOME/.config/btop/btop.conf"
THEME="$1"
COLORSCHEME_FILE="$HOME/.config/kmdot/themes/$THEME/btop.conf"

if [ ! -f "$COLORSCHEME_FILE" ]; then
  echo "ERROR: Theme '$THEME' does not exist for btop."
  exit 1
fi

THEME_VALUE=$(grep "^color_theme" "$COLORSCHEME_FILE" | head -1 | sed 's/^color_theme\s*=\s*//' | tr -d '"')

if grep -q "^color_theme" "$CONFIG_FILE"; then
  sed -i "s|^color_theme.*|color_theme = \"$THEME_VALUE\"|" "$CONFIG_FILE"
else
  sed -i "1i color_theme = \"$THEME_VALUE\"" "$CONFIG_FILE"
fi

echo "✓ Btop theme updated to: $THEME"