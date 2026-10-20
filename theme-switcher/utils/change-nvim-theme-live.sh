#!/usr/bin/env bash

# Exit on Error
set -e

THEME="$1"
COMMAND=":lua vim.cmd('colorscheme $THEME')<CR>"

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
  # Socket files can outlive their Neovim server (for example after a crash).
  # A failed live update must not abort the main theme switcher; the colorscheme
  # file was already written and new Neovim instances will use it normally.
  if ! nvim --server "$SERVER_ADDRESS" --remote-send "$COMMAND" 2>/dev/null; then
    echo "Skipping unavailable nvim server: $SERVER_ADDRESS" >&2
  fi
done
