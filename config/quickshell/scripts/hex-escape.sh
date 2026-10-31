#!/usr/bin/env bash
set -euo pipefail

mode="${1:-}"

unbind_escape() {
  hyprctl eval 'hl.unbind("ESCAPE")' >/dev/null 2>&1 || true
}

case "$mode" in
  bind)
    helper="$HOME/.config/kmdot/quickshell/scripts/hex-escape.sh"
    # This is a consuming compositor bind: Escape cancels Hex without reaching
    # the focused application (for example, a Codex terminal session).
    hyprctl eval "hl.bind(\"ESCAPE\", hl.dsp.exec_cmd(\"$helper cancel\"))" >/dev/null 2>&1
    ;;
  unbind)
    unbind_escape
    ;;
  cancel)
    unbind_escape
    hex dictation cancel >/dev/null 2>&1
    ;;
  *)
    printf 'Usage: %s {bind|unbind|cancel}\n' "$0" >&2
    exit 2
    ;;
esac
