#!/usr/bin/env bash
set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
GHOSTTY_CONFIG_DIR="$HOME/.config/ghostty"
KMDOT_GHOSTTY_CONFIG_DIR="$HOME/.config/kmdot/ghostty"

mkdir -p "$HOME/.config/kmdot"

rm -rf "$KMDOT_GHOSTTY_CONFIG_DIR"
rm -rf "$GHOSTTY_CONFIG_DIR"

cp -r "$REPO_DIR/config/ghostty" "$KMDOT_GHOSTTY_CONFIG_DIR"

ln -sf "$KMDOT_GHOSTTY_CONFIG_DIR" "$GHOSTTY_CONFIG_DIR"

echo "kmDot ghostty config synced!!!"

