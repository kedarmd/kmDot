#!/usr/bin/env bash
set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
NVIM_CONFIG_DIR="$HOME/.config/nvim"
KMDOT_NVIM_CONFIG_DIR="$HOME/.config/kmdot/nvim"

mkdir -p "$HOME/.config/kmdot"

rm -rf "$KMDOT_NVIM_CONFIG_DIR"
rm -rf "$NVIM_CONFIG_DIR"

cp -r "$REPO_DIR/config/nvim" "$KMDOT_NVIM_CONFIG_DIR"

ln -sf "$KMDOT_NVIM_CONFIG_DIR" "$NVIM_CONFIG_DIR"

echo "kmDot nvim config synced!!!"

