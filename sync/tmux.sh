#!/usr/bin/env bash
set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMUX_CONFIG_DIR="$HOME/.config/tmux"
KMDOT_TMUX_CONFIG_DIR="$HOME/.config/kmdot/tmux"

mkdir -p "$HOME/.config/kmdot"

rm -rf "$KMDOT_TMUX_CONFIG_DIR"
rm -rf "$TMUX_CONFIG_DIR"

cp -r "$REPO_DIR/config/tmux" "$KMDOT_TMUX_CONFIG_DIR"

ln -sf "$KMDOT_TMUX_CONFIG_DIR" "$TMUX_CONFIG_DIR"
ln -sf "$TMUX_CONFIG_DIR/tmux.conf" "$HOME/.tmux.conf"

echo "kmDot tmux config synced!!!"
