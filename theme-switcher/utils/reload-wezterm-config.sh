#!/usr/bin/env bash

# Reload wezterm config
SOURCE="$HOME/.config/kmdot/wezterm/wezterm.lua"
TARGET="$HOME/.wezterm.lua"
TEMP_TARGET="$HOME/.temp-wezterm.lua"

touch $TEMP_TARGET
cat "$SOURCE" > "$TEMP_TARGET"
cat "$TEMP_TARGET" > "$TARGET"
rm -rf $TEMP_TARGET

