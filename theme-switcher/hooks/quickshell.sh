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

# Restart quickshell so the bar AND the launchers pick up the new colors together and the
# launcher socket servers re-bind cleanly. (Live-reload re-themes the bar but breaks the
# launcher socket servers — they do not re-bind on reload — which would otherwise force a
# lazy restart via toggle.sh's self-heal on the next launcher open.)
# NOTE: when launched from the quickshell ThemeLauncher, main.sh runs detached
# (setsid nohup … </dev/null) so this pkill can't SIGPIPE it through a closed Process pipe.
if pgrep -x quickshell >/dev/null 2>&1; then
  pkill -x quickshell || true
  for _ in $(seq 1 20); do
    pgrep -x quickshell >/dev/null 2>&1 || break
    sleep 0.1
  done
  setsid nohup quickshell >/dev/null 2>&1 < /dev/null &
fi

echo "✓ Quickshell theme updated to: $THEME"
