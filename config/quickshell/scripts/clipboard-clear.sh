#!/usr/bin/env bash
# Clears the local clipboard history cache. Does not clear the active clipboard.
set -euo pipefail

CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/kmdot/clipboard"
rm -rf "$CACHE"
mkdir -p "$CACHE/text" "$CACHE/img" "$CACHE/thumb"
