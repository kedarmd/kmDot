#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/kmdot/attention-mode"

enabled() {
  [[ -f "$STATE_FILE" ]]
}

case "${1:-status}" in
  status)
    if enabled; then
      printf 'on\n'
    else
      printf 'off\n'
    fi
    ;;
  on)
    mkdir -p "${STATE_FILE%/*}"
    : > "$STATE_FILE"
    hyprctl dispatch 'hl.dsp.dpms({ action = "enable" })' >/dev/null 2>&1 || true
    ;;
  off)
    rm -f "$STATE_FILE"
    ;;
  idle)
    if enabled; then
      exit 0
    fi
    case "${2:-}" in
      lock) loginctl lock-session ;;
      dpms) hyprctl dispatch 'hl.dsp.dpms({ action = "disable" })' ;;
      suspend) systemctl suspend ;;
      *)
        printf 'unknown idle action\n' >&2
        exit 2
        ;;
    esac
    ;;
  *)
    printf 'usage: %s {status|on|off|idle lock|idle dpms|idle suspend}\n' "$0" >&2
    exit 2
    ;;
esac
