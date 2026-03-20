#!/usr/bin/env bash

# Exit on Error
set -e

THEME="$1"
COMMAND=":colorscheme $THEME<CR>"

SERVERS=()

if [ -n "${NVIM_LISTEN_ADDRESS:-}" ] && [ -S "$NVIM_LISTEN_ADDRESS" ]; then
  SERVERS+=("$NVIM_LISTEN_ADDRESS")
fi

shopt -s nullglob
for SERVER_ADDRESS in /tmp/nvim*.sock "/run/user/$UID"/nvim*.sock; do
  if [ -S "$SERVER_ADDRESS" ]; then
    SERVERS+=("$SERVER_ADDRESS")
  fi
done
shopt -u nullglob

if [ "${#SERVERS[@]}" -eq 0 ]; then
  echo "No nvim server socket found"
  exit 0
fi

for SERVER_ADDRESS in "${SERVERS[@]}"; do
  nvim --server "$SERVER_ADDRESS" --remote-send "$COMMAND"
done
