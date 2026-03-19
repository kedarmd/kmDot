#!/usr/bin/env bash
set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ROFI_CONFIG_DIR="$HOME/.config/rofi"
KMDOT_ROFI_CONFIG_DIR="$HOME/.config/kmdot/rofi"

mkdir -p "$HOME/.config/kmdot"

rm -rf "$KMDOT_ROFI_CONFIG_DIR"
rm -rf "$ROFI_CONFIG_DIR"

cp -r "$REPO_DIR/config/rofi" "$KMDOT_ROFI_CONFIG_DIR"

ln -sf "$KMDOT_ROFI_CONFIG_DIR" "$ROFI_CONFIG_DIR"

echo "kmDot rofi config synced!!!"

