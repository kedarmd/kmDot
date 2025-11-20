#!/usr/bin/env bash

# Exit on Error
set -e

THEME="$1"

echo "$THEME"

./hooks/nvim.sh $THEME
./hooks/wezterm.sh $THEME
./hooks/starship.sh $THEME

