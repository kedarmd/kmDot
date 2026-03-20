#!/usr/bin/env bash
set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
STARSHIP_CONFIG_FILE="$HOME/.config/starship.toml"
KMDOT_STARSHIP_CONFIG_DIR="$HOME/.config/kmdot/starship"

mkdir -p "$HOME/.config"

rm -f "$STARSHIP_CONFIG_FILE"

cp -r "$REPO_DIR/config/starship" "$KMDOT_STARSHIP_CONFIG_DIR"

ln -sf "$KMDOT_STARSHIP_CONFIG_DIR/starship.toml" "$STARSHIP_CONFIG_FILE"
echo "kmDot starship config synced!!!"


