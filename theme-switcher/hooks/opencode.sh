#!/usr/bin/env bash

set -e

CONFIG_FILE="$HOME/.config/opencode/tui.json"
THEME="$1"
COLORSCHEME_FILE="$HOME/.config/kmdot/themes/$THEME/opencode.conf"

if [ ! -f "$COLORSCHEME_FILE" ]; then
  echo "ERROR: Theme '$THEME' does not exist for opencode."
  exit 1
fi

THEME_VALUE=$(grep "^theme" "$COLORSCHEME_FILE" | head -1 | sed 's/^theme\s*=\s*//' | tr -d '"')

if grep -q '"theme"' "$CONFIG_FILE"; then
  sed -i "s/\"theme\":.*/\"theme\": \"$THEME_VALUE\",/" "$CONFIG_FILE"
elif grep -q '"provider"' "$CONFIG_FILE"; then
  sed -i '/"provider"/a\  "theme": "'"$THEME_VALUE"'",' "$CONFIG_FILE"
else
  sed -i '1s/^{/{\n  "theme": "'"$THEME_VALUE"'",/' "$CONFIG_FILE"
fi

echo "✓ OpenCode theme updated to: $THEME"
