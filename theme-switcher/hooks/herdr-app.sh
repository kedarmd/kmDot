#!/usr/bin/env bash

# Exit on Error
set -e

CONFIG_DIR="$HOME/.config/herdr-app"
THEME="$1"
COLORSCHEME_FILE="$HOME/.config/kmdot/themes/$THEME/herdr-app.json"

if [ ! -f "$COLORSCHEME_FILE" ]; then
  echo "ERROR: Theme '$THEME' does not exist for herdr-app."
  exit 1
fi

# herdr-app is opt-in: skip when it was never installed (no home to theme).
# NOTE: this file is sourced by main.sh — use return, never exit, so a skip
# doesn't terminate the whole theme run.
if [ ! -d "$CONFIG_DIR" ]; then
  echo "(herdr-app not installed — skipping)" >&2
  return 0
fi

# The shown layout and settings.json both name the fixed theme "kmdot-active",
# so a switch rewrites that one file. Copy via a temp file + move so the app
# never reads a half-written palette.
mkdir -p "$CONFIG_DIR/themes"
TMP_FILE="$CONFIG_DIR/themes/.kmdot-active.json.swt"
cp "$COLORSCHEME_FILE" "$TMP_FILE"
mv -f "$TMP_FILE" "$CONFIG_DIR/themes/kmdot-active.json"

# Re-resolve the theme in a running window; the next launch reads the file
# either way, so a missing window/command is not an error.
RELOAD_MSG="applies on next herdr-app launch"
if command -v herdr-app >/dev/null 2>&1 && herdr-app status >/dev/null 2>&1; then
  if herdr-app do app.theme --name kmdot-active >/dev/null 2>&1; then
    RELOAD_MSG="live window reloaded"
  fi
fi

echo "✓ Herdr App theme updated to: $THEME ($RELOAD_MSG)"
