#!/usr/bin/env bash
set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
STARSHIP_CONFIG_FILE="$HOME/.config/starship.toml"
KMDOT_STARSHIP_CONFIG_FILE="$REPO_DIR/config/starship/starship.toml"

mkdir -p "$HOME/.config"

rm -f "$STARSHIP_CONFIG_FILE"

cp "$KMDOT_STARSHIP_CONFIG_FILE" "$HOME/.config/starship.toml"

echo "kmDot starship config synced!!!"


