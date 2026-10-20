#!/usr/bin/env bash
set -euo pipefail

THEME="$1"
SDDM_HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE="$HOME/.config/kmdot/themes/$THEME/quickshell.conf"
if [ ! -f "$SOURCE" ]; then
  SOURCE="$(cd "$SDDM_HOOK_DIR/../.." && pwd)/themes/$THEME/quickshell.conf"
fi
TARGET="/var/tmp/kmdot-sddm-theme.conf"
TEMP="${TARGET}.tmp.$$"

if [ ! -f "$SOURCE" ]; then
  echo "ERROR: Theme '$THEME' has no Quickshell palette at $SOURCE" >&2
  exit 1
fi

{
  printf '%s\n' 'background=/var/tmp/kmdot-current.png'
  printf '%s\n' 'fontFamily=JetBrainsMono Nerd Font Propo'
  while IFS='=' read -r key value; do
    case "$key" in
      base|surface|surface_alt|text|text_alt|border|primary|on_primary|error)
        printf '%s=%s\n' "$key" "$value"
        ;;
    esac
  done < "$SOURCE"
} > "$TEMP"

chmod 644 "$TEMP"
mv -f "$TEMP" "$TARGET"
