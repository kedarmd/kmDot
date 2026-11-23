#!/usr/bin/env bash
set -e
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KMDOT_CONFIG_DIR="$HOME/.config/kmdot/opencode"
CONFIG_DIR="$HOME/.config/opencode"
mkdir -p "$HOME/.config/kmdot"
if [[ -e "$CONFIG_DIR" && ! -L "$CONFIG_DIR" ]]; then
  mkdir -p "$KMDOT_CONFIG_DIR"
  cp -a "$CONFIG_DIR"/. "$KMDOT_CONFIG_DIR"/
fi
mkdir -p "$KMDOT_CONFIG_DIR"
cp -a "$REPO_DIR/config/opencode"/. "$KMDOT_CONFIG_DIR"/
rm -rf "$CONFIG_DIR"
ln -s "$KMDOT_CONFIG_DIR" "$CONFIG_DIR"
echo "kmDot opencode config synced!!!"
