#!/usr/bin/env bash
# Clipboard history daemon: watches the Wayland clipboard and hands every new
# selection to clipboard-capture.sh. Launched from hyprland autostart.
# Idempotent: refuses to start a second watcher set.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/kmdot/clipboard"
CAPTURE="$SCRIPT_DIR/clipboard-capture.sh"

mkdir -p "$CACHE/text" "$CACHE/img" "$CACHE/thumb"

# Prune stale entries (older than the TTL) so a previous session's history
# doesn't survive beyond a day.
if [ -f "$SCRIPT_DIR/clipboard-list.sh" ]; then
  "$SCRIPT_DIR/clipboard-list.sh" >/dev/null 2>&1 || true
fi

if pgrep -f "wl-paste .*--watch.*clipboard-capture" >/dev/null 2>&1; then
  exit 0
fi

wl-paste --watch "$CAPTURE" &
text_pid=$!

# The default watcher does not reliably fire for image-only offers here, so run
# a dedicated PNG watcher for hyprshot/screenshots and image clipboard payloads.
wl-paste --type image/png --watch "$CAPTURE" &
image_pid=$!

trap 'kill "$text_pid" "$image_pid" 2>/dev/null || true' INT TERM EXIT
wait
