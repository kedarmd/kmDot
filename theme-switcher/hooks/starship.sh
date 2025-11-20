#!/usr/bin/env bash

# Exit on Error
set -e

THEME="$1"

THEME_FILE="$HOME/.config/kmdot/themes/$THEME/starship.toml"
CONFIG_FILE="$HOME/.config/kmdot/starship/starship.toml"

if [ ! -f "$THEME_FILE" ]; then
  echo "ERROR: No config found for theme '$THEME'"
  exit 1
fi

cat "$THEME_FILE" > "$CONFIG_FILE"
