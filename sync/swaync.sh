#!/usr/bin/env bash
set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SWAYNC_CONFIG_DIR="$HOME/.config/swaync"
KMDOT_SWAYNC_CONFIG_DIR="$HOME/.config/kmdot/swaync"

mkdir -p "$HOME/.config/kmdot"

rm -rf "$KMDOT_SWAYNC_CONFIG_DIR"
rm -rf "$SWAYNC_CONFIG_DIR"

cp -r "$REPO_DIR/config/swaync" "$KMDOT_SWAYNC_CONFIG_DIR"

ln -sf "$KMDOT_SWAYNC_CONFIG_DIR" "$SWAYNC_CONFIG_DIR"

echo "kmDot swaync config synced!!!"
