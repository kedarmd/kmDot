#!/usr/bin/env bash

# Exit on Error
set -e

KMDOT_CONFIG_DIR="$HOME/.config/kmdot"

if [ ! -f $KMDOT_CONFIG_DIR ]; then
  mkdir "$KMDOT_CONFIG_DIR"
  cp -r ./config/* "$KMDOT_CONFIG_DIR"
  # Sync Nvim
  ./sync/nvim.sh
fi


