#!/usr/bin/env bash
# kmDot Server Mode control.
#
# Server mode turns the laptop into a headless part-time server:
#   * holds a logind sleep inhibitor (blocks suspend/hibernate + lid-close
#     suspend) so the laptop stays awake while unattended — the screen still
#     dims/locks/offs per the normal hypridle config, but the machine never
#     actually suspends, so Tailscale + Jellyfin keep serving
#   * starts/stops the tailscaled + jellyfin services
#   * suspends background apps that would otherwise drain the battery
#   * the screen is left entirely to the normal hypridle configuration (no
#     custom dim/lock/DPMS in server mode)
#
# Usage:
#   server-mode.sh status                        print key=value status lines
#   server-mode.sh on|off [--no-services]        enable/disable server mode;
#                                                --no-services skips starting/
#                                                stopping tailscaled+jellyfin
#   server-mode.sh service <name> <action>       start|stop|restart a service
#   server-mode.sh config <key> <value>          write ~/.config/kmdot/server-mode.conf
set -euo pipefail

CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/kmdot"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/kmdot"
CONF_FILE="$CONF_DIR/server-mode.conf"
MARKER="$CONF_DIR/server-mode"
UNIT="kmdot-server-mode"

mkdir -p "$CONF_DIR" "$CACHE_DIR"

# conf_val KEY DEFAULT — read a key from the conf file (tolerates missing file).
conf_val() {
  local key="$1" def="${2:-}"
  local val="$def"
  if [[ -f "$CONF_FILE" ]]; then
    val="$(awk -F= -v k="$key" '$1==k {sub(/^[ \t]+/,"",$2); sub(/[ \t]+$/,"",$2); print $2}' "$CONF_FILE" | tail -1)"
    [[ -n "$val" ]] || val="$def"
  fi
  printf '%s' "$val"
}

USER_SERVICES="$(conf_val user_services 'app-blueman@autostart.service')"
SYSTEM_SERVICES="$(conf_val system_services 'docker.service containerd.service')"
PROCESSES="$(conf_val processes 'kmdot-music uvicorn')"

start_inhibitor() {
  # Transient user unit holding a logind inhibitor. While it runs,
  # sleep/hibernate/lid-close are blocked: hypridle still dims/locks the screen
  # per the normal config, but `systemctl suspend` is refused, so the laptop
  # stays awake and keeps serving. `sleep infinity` is the holder process; when
  # the unit stops the inhibitor is released and the unit is collected.
  systemd-run --user --unit="$UNIT" --collect \
    systemd-inhibit --what=sleep:handle-lid-switch --mode=block \
    --who="kmDot Server Mode" --why="Server mode active" \
    sleep infinity
}

stop_inhibitor() {
  systemctl --user stop "$UNIT" 2>/dev/null || true
}

stop_background_apps() {
  for s in $USER_SERVICES; do
    # The provider manager exclusively owns Handy and Hex.
    [[ "$s" == "app-Handy@autostart.service" ]] && continue
    systemctl --user stop "$s" >/dev/null 2>&1 || true
  done
  "$HOME/.config/kmdot/quickshell/scripts/dictation-provider.sh" stop >/dev/null 2>&1 || true
  for s in $SYSTEM_SERVICES; do
    systemctl stop "$s" >/dev/null 2>&1 || true
  done
  for p in $PROCESSES; do
    pkill -x "$p" >/dev/null 2>&1 || true
  done
}

start_background_apps() {
  for s in $USER_SERVICES; do
    [[ "$s" == "app-Handy@autostart.service" ]] && continue
    systemctl --user start "$s" >/dev/null 2>&1 || true
  done
  "$HOME/.config/kmdot/quickshell/scripts/dictation-provider.sh" start >/dev/null 2>&1 || true
  for s in $SYSTEM_SERVICES; do
    systemctl start "$s" >/dev/null 2>&1 || true
  done
}

cmd_status() {
  local mode=off
  [[ -f "$MARKER" ]] && mode="$(cat "$MARKER")"
  local inhibitor
  inhibitor="$(systemctl --user is-active "$UNIT" 2>/dev/null || true)"
  local ts jf ip=""
  ts="$(systemctl is-active tailscaled 2>/dev/null || true)"
  jf="$(systemctl is-active jellyfin 2>/dev/null || true)"
  if [[ "$ts" == "active" ]]; then
    ip="$(tailscale ip -4 2>/dev/null | head -1 || true)"
  fi
  printf 'mode=%s\n' "$mode"
  printf 'inhibitor=%s\n' "$inhibitor"
  printf 'tailscale=%s\n' "$ts"
  printf 'tailscale_ip=%s\n' "$ip"
  printf 'jellyfin=%s\n' "$jf"
}

cmd_on() {
  local manage_services=1
  [[ "${1:-}" == "--no-services" ]] && manage_services=0
  start_inhibitor
  stop_background_apps
  if (( manage_services )); then
    if ! systemctl start tailscaled jellyfin; then
      echo "warning: could not start tailscaled/jellyfin (is the polkit rule installed?)" >&2
    fi
  fi
  echo on > "$MARKER"
}

cmd_off() {
  local manage_services=1
  [[ "${1:-}" == "--no-services" ]] && manage_services=0
  stop_inhibitor
  if (( manage_services )); then
    if ! systemctl stop tailscaled jellyfin; then
      echo "warning: could not stop tailscaled/jellyfin (is the polkit rule installed?)" >&2
    fi
  fi
  start_background_apps
  rm -f "$MARKER"
}

cmd_service() {
  local name="${1:-}" action="${2:-}"
  case "$name" in
    tailscale) systemctl "$action" tailscaled ;;
    jellyfin) systemctl "$action" jellyfin ;;
    *) echo "unknown service: $name" >&2; exit 1 ;;
  esac
}

cmd_config() {
  local key="${1:-}" val="${2:-}"
  [[ -n "$key" ]] || { echo "usage: server-mode.sh config <key> <value>" >&2; exit 1; }
  if [[ -f "$CONF_FILE" ]]; then
    grep -v "^${key}=" "$CONF_FILE" > "$CONF_FILE.tmp" || true
    mv "$CONF_FILE.tmp" "$CONF_FILE"
  fi
  printf '%s=%s\n' "$key" "$val" >> "$CONF_FILE"
}

case "${1:-}" in
  status) cmd_status ;;
  on) shift; cmd_on "$@" ;;
  off) shift; cmd_off "$@" ;;
  service) shift; cmd_service "$@" ;;
  config) shift; cmd_config "$@" ;;
  *)
    echo "usage: server-mode.sh {status|on|off [--no-services]|service <tailscale|jellyfin> <start|stop|restart>|config <key> <value>}" >&2
    exit 1
    ;;
esac
