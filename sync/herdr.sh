#!/usr/bin/env bash
set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HERDR_CONFIG_DIR="$HOME/.config/herdr"
KMDOT_HERDR_CONFIG_DIR="$HOME/.config/kmdot/herdr"

mkdir -p "$HOME/.config/kmdot"

rm -rf "$KMDOT_HERDR_CONFIG_DIR"
rm -rf "$HERDR_CONFIG_DIR"

cp -r "$REPO_DIR/config/herdr" "$KMDOT_HERDR_CONFIG_DIR"

ln -sf "$KMDOT_HERDR_CONFIG_DIR" "$HERDR_CONFIG_DIR"

echo "kmDot herdr config synced!!!"
