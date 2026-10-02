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

if [ ! -f "$CONFIG_FILE" ]; then
  # opencode is opt-in: skip when it was never installed (no config to theme).
  # NOTE: this file is sourced by main.sh — use return, never exit, so a
  # skip doesn't terminate the whole theme run.
  echo "(opencode not installed — skipping)" >&2
  return 0
fi

jq --arg theme "$THEME_VALUE" '.theme = $theme' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"

KV_FILE="$HOME/.local/share/opencode/kv.json"
if [ -f "$KV_FILE" ]; then
  jq --arg theme "$THEME_VALUE" '.theme = $theme' "$KV_FILE" > "$KV_FILE.tmp" && mv "$KV_FILE.tmp" "$KV_FILE"
fi

echo "✓ OpenCode theme updated to: $THEME_VALUE (applies on next launch)"