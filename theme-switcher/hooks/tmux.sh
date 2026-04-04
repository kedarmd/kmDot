#!/usr/bin/env bash

# Exit on Error
set -e

CONFIG_FILE="$HOME/.config/kmdot/tmux/colors.conf"
THEME="$1"
COLORSCHEME_FILE="$HOME/.config/kmdot/themes/$THEME/tmux.conf"

# Check if theme file exists
if [ ! -f "$COLORSCHEME_FILE" ]; then
  echo "ERROR: Theme '$THEME' does not exist for tmux."
  exit 1
fi

cat "$COLORSCHEME_FILE" > "$CONFIG_FILE"

if command -v tmux >/dev/null 2>&1; then
  if tmux list-sessions >/dev/null 2>&1; then
    tmux source-file "$HOME/.config/tmux/tmux.conf"
  fi
fi

echo "✓ Tmux theme updated to: $THEME"
