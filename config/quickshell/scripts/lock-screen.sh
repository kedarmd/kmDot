#!/usr/bin/env bash
set -euo pipefail

# Ensure the long-lived shell owns the protocol lock surfaces before asking it
# to lock. The no-duplicate flag prevents racing a second copy of the bar.
if ! quickshell ipc call lockscreen isLocked >/dev/null 2>&1; then
  quickshell --no-duplicate --daemonize >/dev/null 2>&1 || true
fi

for _ in $(seq 1 50); do
  if quickshell ipc call lockscreen lock >/dev/null 2>&1; then
    exit 0
  fi
  sleep 0.1
done

notify-send -u critical "Lock screen unavailable" "Quickshell did not accept the session lock request." 2>/dev/null || true
exit 1
