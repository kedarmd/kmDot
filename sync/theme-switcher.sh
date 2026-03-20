#!/usr/bin/env bash
set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KMDOT_THEME_SWITCHER_CONFIG_DIR="$HOME/.config/kmdot/theme-switcher"
KMDOT_THEME_DIR="$HOME/.config/kmdot/themes"

mkdir -p "$HOME/.config/kmdot"

rm -rf "$KMDOT_THEME_SWITCHER_CONFIG_DIR"
rm -rf "$KMDOT_THEME_DIR"

cp -r "$REPO_DIR/theme-switcher" "$KMDOT_THEME_SWITCHER_CONFIG_DIR"
cp -r "$REPO_DIR/themes" "$KMDOT_THEME_DIR"

echo "kmDot theme-switcher config synced!!!"

