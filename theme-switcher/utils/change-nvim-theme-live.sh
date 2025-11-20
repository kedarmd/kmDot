#!/usr/bin/env bash

# Exit on Error
set -e

THEME="$1"
COMMAND=":colorscheme $THEME<CR>"

NVIM_PIDS=$(pgrep nvim)

if [ -z "$NVIM_PIDS" ]; then
  echo "No running nvim process found"
  exit 1
fi

for PID in $NVIM_PIDS; do
  SERVER_ADDRESS="/tmp/nvim-$PID.sock"
  if [ -S "$SERVER_ADDRESS" ]; then
    nvim --server  "$SERVER_ADDRESS" --remote-send "$COMMAND"
  fi
done
