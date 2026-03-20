#!/usr/bin/env bash
set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FISH_CONFIG_DIR="$HOME/.config/fish"
KMDOT_FISH_CONFIG_DIR="$HOME/.config/kmdot/fish"

mkdir -p "$HOME/.config/kmdot"

rm -rf "$KMDOT_FISH_CONFIG_DIR"
rm -rf "$FISH_CONFIG_DIR"

cp -r "$REPO_DIR/config/fish" "$KMDOT_FISH_CONFIG_DIR"

ln -sf "$KMDOT_FISH_CONFIG_DIR" "$FISH_CONFIG_DIR"

echo "kmDot fish config synced!!!"


