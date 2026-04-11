#!/usr/bin/env bash

# Exit on Error
set -e

CONFIG_FILE="$HOME/.config/kmdot/swaync/style.css"
THEME="$1"
COLORSCHEME_FILE="$HOME/.config/kmdot/themes/$THEME/swaync.css"

# Check if theme file exists
if [ ! -f "$COLORSCHEME_FILE" ]; then
  echo "ERROR: Theme '$THEME' does not exist for swaync."
  exit 1
fi

cat "$COLORSCHEME_FILE" > "$CONFIG_FILE"

if command -v swaync-client &>/dev/null; then
  swaync-client -rs >/dev/null 2>&1 || true
fi

echo "✓ Swaync theme updated to: $THEME"
