#!/usr/bin/env bash
# Copy a clipboard-history entry back to the Wayland clipboard.
set -euo pipefail

if [ "$#" -ne 1 ]; then
  printf 'usage: %s <hash>\n' "$(basename "$0")" >&2
  exit 2
fi

CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/kmdot/clipboard"
HASH="$1"

case "$HASH" in
  *[!0-9a-f]*) exit 2 ;;
esac

if [ -f "$CACHE/img/$HASH.png" ]; then
  wl-copy --type image/png < "$CACHE/img/$HASH.png"
elif [ -f "$CACHE/text/$HASH" ]; then
  wl-copy < "$CACHE/text/$HASH"
else
  exit 1
fi
