#!/usr/bin/env bash
# Smoke checks for a freshly installed kmDot Arch workstation.
# Run inside the target user's active Hyprland session after install/config sync.
set -uo pipefail

export PATH="$HOME/.local/share/mise/shims:$HOME/.local/bin:$PATH"

# SSH and cron do not inherit the compositor's environment. When the test is
# run remotely, recover the Wayland/Hyprland variables from the running shell.
if [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
  qshell_pid="$(pgrep -xo quickshell || true)"
  if [[ -n "$qshell_pid" && -r "/proc/$qshell_pid/environ" ]]; then
    while IFS= read -r -d '' item; do
      case "$item" in
        WAYLAND_DISPLAY=*|HYPRLAND_INSTANCE_SIGNATURE=*|DISPLAY=*|XDG_RUNTIME_DIR=*)
          export "$item"
          ;;
      esac
    done <"/proc/$qshell_pid/environ"
  fi
fi

PASS_COUNT=0
FAIL_COUNT=0

check() {
  local name="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    printf 'PASS  %s\n' "$name"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    printf 'FAIL  %s\n' "$name"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

check_nvim() {
  local tmp
  tmp="$(mktemp)" || return 1
  if nvim --headless -u "$HOME/.config/nvim/init.lua" \
    -c 'lua assert(vim.g.mapleader == " ")' \
    -c 'call setline(1, "KMDOT_NVIM_OK")' \
    -c "write! $tmp" -c 'qa!' >/dev/null 2>&1 \
    && grep -qx 'KMDOT_NVIM_OK' "$tmp"; then
    rm -f "$tmp"
    return 0
  fi
  rm -f "$tmp"
  return 1
}

check_tmux() {
  local session="kmdot-smoke-$$"
  local config="$HOME/.config/tmux/tmux.conf"
  tmux -f "$config" new-session -d -s "$session" || return 1
  if ! tmux -f "$config" list-sessions -F '#S' | grep -qx "$session"; then
    tmux -f "$config" kill-session -t "$session" >/dev/null 2>&1 || true
    return 1
  fi
  tmux -f "$config" kill-session -t "$session"
}

check_hyprland() {
  local errors
  pgrep -x Hyprland >/dev/null || return 1
  errors="$(hyprctl configerrors 2>/dev/null)" || return 1
  [[ -z "$errors" ]] || return 1
  hyprctl -j monitors | jq -e 'length > 0' >/dev/null
}

check_handy() {
  local models
  models="$(mktemp)" || return 1
  if handy --list-models --json >"$models" 2>/dev/null \
    && jq -e 'length > 0' "$models" >/dev/null; then
    rm -f "$models"
    return 0
  fi
  rm -f "$models"
  return 1
}

check_no_foreign_packages() {
  local foreign
  foreign="$(pacman -Qm 2>/dev/null || true)"
  [[ -z "$foreign" ]]
}

check_quickshell_launcher() {
  [[ -n "${WAYLAND_DISPLAY:-}" ]] || return 1
  pgrep -x quickshell >/dev/null || return 1
  timeout 5s qs ipc call kmdot-launcher ping | grep -qx 'ok' || return 1
  timeout 5s qs ipc call kmdot-launcher showApplications >/dev/null || return 1
  [[ "$(timeout 5s qs ipc call kmdot-launcher isOpen)" == true ]] || return 1
  timeout 5s qs ipc call kmdot-launcher hide >/dev/null || return 1
  [[ "$(timeout 5s qs ipc call kmdot-launcher isOpen)" == false ]]
}

check 'Neovim config starts, edits, and writes a buffer' check_nvim
check 'Hyprland session, loaded config, and monitor API are live' check_hyprland
check 'Quickshell IPC and app launcher open/close' check_quickshell_launcher
check 'Ghostty starts' ghostty --version
check 'Herdr upstream CLI starts' herdr --version
check 'Zen Browser starts' zen --version
check 'Firefox starts' firefox --version
check 'Zed CLI starts' zed --version
check 'OpenCode CLI starts' mise exec -- opencode --version
check 'Handy loads its model catalog' check_handy
check 'Fish startup succeeds' fish -c 'printf fish-ok'
check 'Starship CLI starts' starship --version
check 'Tmux config creates and closes a session' check_tmux
check 'SDDM is enabled for boot' systemctl is-enabled sddm.service
check 'NetworkManager is active' systemctl is-active NetworkManager.service
check 'en_IN.UTF-8 locale is generated' bash -c 'LC_ALL=C locale -a | grep -qi "^en_IN\.utf8$"'
check 'No foreign/AUR packages are installed' check_no_foreign_packages

printf '\nFresh Arch smoke checks: %d passed, %d failed.\n' "$PASS_COUNT" "$FAIL_COUNT"
(( FAIL_COUNT == 0 ))
