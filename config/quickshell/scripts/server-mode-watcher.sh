#!/usr/bin/env bash
# kmDot server-mode screen watcher.
#
# Runs as the process of the kmdot-server-mode user unit (wrapped by
# systemd-inhibit, which holds the sleep lock while this runs). Handles the
# server-mode screen policy:
#
#   * After `timeout` minutes of no activity, turn the screen off (DPMS) or dim
#     the backlight to minimum (`screen=off|dim` in server-mode.conf).
#   * On any user interaction while the screen is off, wake the screen and exit
#     server mode. The hand-off to `server-mode.sh off` runs in its own
#     transient unit so it survives this unit being stopped.
#   * While the user is actively using the machine, activity only resets the idle
#     timer; server mode stays on.
#
# Activity detection is deliberately NOT Hyprland socket2 `keyboardkey` /
# `mousebutton` events (they don't fire for bound keys or virtual keyboards):
# instead it polls logind's `IdleHint` for the active seat0 session (real
# keyboard/mouse/touchpad input at the kernel level) plus `hyprctl cursorpos`
# for pure mouse movement.
#
# Config is re-read every pass, so changes from the dropdown apply live.
set -uo pipefail

CONF="$HOME/.config/kmdot/server-mode.conf"
SCREEN_OFF="$HOME/.cache/kmdot/server-screen-off"
SCREEN_BRIGHT="$HOME/.cache/kmdot/server-screen-off.brightness"
SCRIPT="$HOME/.config/kmdot/quickshell/scripts/server-mode.sh"
POLL=0.5

# conf_val KEY DEFAULT — read a key from the conf file (tolerates missing file).
conf_val() {
  local key="$1" def="${2:-}"
  local val="$def"
  if [[ -f "$CONF" ]]; then
    val="$(awk -F= -v k="$key" '$1==k {sub(/^[ \t]+/,"",$2); sub(/[ \t]+$/,"",$2); print $2}' "$CONF" | tail -1)"
    [[ -n "$val" ]] || val="$def"
  fi
  printf '%s' "$val"
}

# active_session_id — prints the active seat0 user session id (empty if none).
active_session_id() {
  loginctl list-sessions --no-legend 2>/dev/null \
    | awk '$4=="seat0" && $6=="user" && $8=="yes" {print $1; exit}'
}

# logind_idle — returns 0 if the session is idle, 1 if active, 2 if unknown.
logind_idle() {
  local sid hint
  sid="$(active_session_id)"
  [[ -n "$sid" ]] || return 2
  hint="$(loginctl show-session "$sid" -p IdleHint 2>/dev/null)"
  case "$hint" in
    IdleHint=yes) return 0 ;;
    IdleHint=no) return 1 ;;
  esac
  return 2
}

screen_is_off() {
  [[ -f "$SCREEN_OFF" ]]
}

turn_screen_off() {
  local screen="$1"
  if [[ "$screen" == "dim" ]]; then
    local cur
    cur="$(brightnessctl get 2>/dev/null || true)"
    if [[ -n "$cur" ]]; then
      printf '%s' "$cur" > "$SCREEN_BRIGHT" 2>/dev/null || true
    fi
    brightnessctl set 1 >/dev/null 2>&1 || true
  else
    hyprctl dispatch dpms off >/dev/null 2>&1 || true
  fi
  printf '1' > "$SCREEN_OFF" 2>/dev/null || true
}

wake_screen() {
  local screen="$1"
  if [[ "$screen" == "dim" ]]; then
    local b
    b="$(cat "$SCREEN_BRIGHT" 2>/dev/null || true)"
    if [[ -n "$b" ]]; then
      brightnessctl set "$b" >/dev/null 2>&1 || true
    fi
  else
    hyprctl dispatch dpms on >/dev/null 2>&1 || true
  fi
  rm -f "$SCREEN_OFF" "$SCREEN_BRIGHT"
}

exit_server_mode() {
  # Wake first so the screen is usable immediately, then hand the full shutdown
  # (services, apps, inhibitor) to server-mode.sh running in its own transient
  # unit -- `systemctl stop` kills everything in THIS unit's cgroup, which would
  # otherwise kill the hand-off script mid-run. systemd-run starts the unit and
  # returns once it is active, so the hand-off survives this unit ending.
  local screen="$1"
  wake_screen "$screen"
  systemd-run --user --collect --unit=kmdot-server-mode-wake \
    "$SCRIPT" off >/dev/null 2>&1 || true
}

main() {
  local timeout_min screen timeout last_activity now cur last_cursor off rc
  timeout_min="$(conf_val timeout 5)"
  screen="$(conf_val screen off)"
  timeout=$((timeout_min * 60))
  last_activity="$(date +%s)"
  last_cursor="$(hyprctl cursorpos 2>/dev/null || true)"
  off=0
  screen_is_off && off=1

  while true; do
    now="$(date +%s)"

    # Mouse movement: cursor moved since last poll (also re-wakes DPMS via
    # Hyprland's misc:mouse_move_enables_dpms, but we own the exit).
    cur="$(hyprctl cursorpos 2>/dev/null || true)"
    if [[ -n "$cur" && "$cur" != "$last_cursor" ]]; then
      last_cursor="$cur"
      last_activity="$now"
      if (( off )); then
        exit_server_mode "$screen"
        return
      fi
    fi

    # Keyboard / mouse button / touch: logind IdleHint flips to no on input.
    logind_idle
    rc=$?
    if [[ $rc -eq 1 ]]; then
      last_activity="$now"
      if (( off )); then
        exit_server_mode "$screen"
        return
      fi
    fi

    # Re-read config each pass so dropdown changes apply live.
    timeout_min="$(conf_val timeout 5)"
    screen="$(conf_val screen off)"
    timeout=$((timeout_min * 60))

    if (( timeout > 0 )) && (( ! off )) && (( now - last_activity > timeout )); then
      turn_screen_off "$screen"
      off=1
    fi

    sleep "$POLL"
  done
}

main