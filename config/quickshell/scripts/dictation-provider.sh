#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/kmdot"
PROVIDER_FILE="$CONFIG_DIR/dictation-provider"
PROVIDER=""
HANDY_BIN="$(command -v handy || true)"
[[ -n "$HANDY_BIN" ]] || HANDY_BIN="$HOME/.local/bin/handy"
HEX_BIN="$(command -v hex || true)"
[[ -n "$HEX_BIN" ]] || HEX_BIN="$HOME/.local/bin/hex"

read_provider() {
  local value
  value="$(cat "$PROVIDER_FILE" 2>/dev/null || true)"
  case "$value" in handy|hex) printf '%s' "$value" ;; *) printf 'handy' ;; esac
}

hex_busy() {
  [[ -x "$HEX_BIN" ]] || return 1
  "$HEX_BIN" status --json 2>/dev/null | grep -Eiq '"state"[[:space:]]*:[[:space:]]*"(recording|transcribing|processing|dictating)'
}

stop_hex() {
  if hex_busy; then
    echo "Hex is recording or transcribing; finish or cancel it before switching apps." >&2
    return 1
  fi
  if [[ -x "$HEX_BIN" ]]; then "$HEX_BIN" quit >/dev/null 2>&1 || true; fi
  systemctl --user stop hex.service >/dev/null 2>&1 || true
}

stop_handy() {
  if pgrep -x handy >/dev/null 2>&1; then
    "$HANDY_BIN" --cancel >/dev/null 2>&1 || true
    pkill -x handy >/dev/null 2>&1 || true
  fi
  systemctl --user stop app-Handy@autostart.service >/dev/null 2>&1 || true
}

start_provider() {
  case "$1" in
    handy)
      stop_hex
      if [[ ! -x "$HANDY_BIN" ]]; then echo "Handy executable not found: $HANDY_BIN" >&2; return 1; fi
      if ! pgrep -x handy >/dev/null 2>&1; then
        nohup "$HANDY_BIN" --start-hidden >/dev/null 2>&1 </dev/null &
      fi
      ;;
    hex)
      stop_handy
      if [[ ! -x "$HEX_BIN" ]]; then echo "Hex executable not found: $HEX_BIN" >&2; return 1; fi
      if systemctl --user cat hex.service >/dev/null 2>&1; then
        systemctl --user start hex.service
      else
        nohup "$HEX_BIN" start >/dev/null 2>&1 </dev/null &
      fi
      ;;
    *) echo "Unknown dictation provider: $1" >&2; return 2 ;;
  esac
}

case "${1:-get}" in
  get) read_provider; echo ;;
  start)
    mkdir -p "$CONFIG_DIR"
    start_provider "$(read_provider)"
    ;;
  stop)
    case "$(read_provider)" in
      handy) stop_handy ;;
      hex) stop_hex ;;
    esac
    ;;
  toggle)
    case "$(read_provider)" in
      handy) exec "$0" set hex ;;
      hex) exec "$0" set handy ;;
    esac
    ;;
  set)
    target="${2:-}"
    [[ "$target" == handy || "$target" == hex ]] || { echo 'Usage: dictation-provider.sh set {handy|hex}' >&2; exit 2; }
    mkdir -p "$CONFIG_DIR"
    old="$(read_provider)"
    if [[ "$old" != "$target" ]]; then
      if ! start_provider "$target"; then
        start_provider "$old" >/dev/null 2>&1 || true
        exit 1
      fi
      tmp="$PROVIDER_FILE.$$"
      printf '%s\n' "$target" > "$tmp"
      mv -f -- "$tmp" "$PROVIDER_FILE"
    fi
    ;;
  launcher)
    case "$(read_provider)" in
      handy) exec "$HOME/.config/kmdot/quickshell/scripts/toggle.sh" kmdot-handy-launcher ;;
      hex) exec "$HOME/.config/kmdot/quickshell/scripts/toggle.sh" kmdot-hex-launcher ;;
    esac
    ;;
  configure-autostart)
    # The provider supervisor is the only startup owner. Disable the app-owned
    # routes so an inactive provider cannot be resurrected at login.
    if [[ ! -s "$PROVIDER_FILE" ]]; then
      mkdir -p "$CONFIG_DIR"
      if systemctl --user is-active --quiet hex.service; then PROVIDER=hex
      elif pgrep -x handy >/dev/null 2>&1; then PROVIDER=handy
      else PROVIDER=handy
      fi
      printf '%s\n' "$PROVIDER" > "$PROVIDER_FILE"
    fi
    systemctl --user disable --now app-Handy@autostart.service >/dev/null 2>&1 || true
    systemctl --user mask app-Handy@autostart.service >/dev/null 2>&1 || true
    if [[ -x "$HEX_BIN" ]]; then "$HEX_BIN" launch-at-login off >/dev/null 2>&1 || true; fi
    systemctl --user disable --now hex.service >/dev/null 2>&1 || true
    ;;
  dictate)
    case "$(read_provider)" in
      handy) exec "$HANDY_BIN" --toggle-transcription ;;
      hex) exec "$HEX_BIN" dictation toggle ;;
    esac
    ;;
  *) echo "Usage: dictation-provider.sh {get|start|stop|set|toggle|dictate|launcher|configure-autostart}" >&2; exit 2 ;;
esac
