#!/usr/bin/env bash

# Exit on Error
set -e

CONFIG_FILE="$HOME/.config/kmdot/quickshell/Colors.qml"
THEME="$1"
COLORSCHEME_FILE="$HOME/.config/kmdot/themes/$THEME/quickshell.conf"

# Check if theme file exists
if [ ! -f "$COLORSCHEME_FILE" ]; then
  echo "ERROR: Theme '$THEME' does not exist for quickshell."
  exit 1
fi

{
  echo "pragma Singleton"
  echo "import QtQuick"
  echo "import Quickshell"
  echo ""
  echo "Singleton {"
  while IFS='=' read -r key value; do
    case "$key" in
      ""|\#*) continue ;;
    esac
    echo "  readonly property color $key: \"$value\""
  done < "$COLORSCHEME_FILE"
  echo "}"
} > "$CONFIG_FILE"

# Quickshell watches its config dir and live-reloads on file change; no restart needed

echo "✓ Quickshell theme updated to: $THEME"
