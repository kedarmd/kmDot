#!/usr/bin/env bash
# Toggle a kmDot quickshell launcher by socket name (kmdot-launcher, kmdot-system, ...).
# Self-heals: if the socket is missing (quickshell live-reloaded after a theme switch
# and unlinked it, or quickshell is not running), restarts quickshell and retries.
set -euo pipefail

SOCK_NAME="${1:?usage: toggle.sh <sockname>}"
SOCK="${XDG_RUNTIME_DIR:-/tmp}/${SOCK_NAME}.sock"

connect() {
  python3 - "$SOCK" <<'EOF'
import socket, sys
path = sys.argv[1]
s = socket.socket(socket.AF_UNIX)
try:
    s.settimeout(3)
    s.connect(path)
finally:
    s.close()
EOF
}

if [[ -S "$SOCK" ]] && connect 2>/dev/null; then
  exit 0
fi

# Socket missing OR stale (file present but no server listening, e.g. quickshell
# died, or a theme switch live-reloaded and the old SocketServer unlinked the
# socket after the new one bound). Restart quickshell and retry.
notify-send "kmDot" "Restarting quickshell to restore launchers…"
# pkill exits 1 when quickshell is already dead (exactly the case we're healing),
# and `set -e` would abort the script before the restart — so guard it.
pkill -x quickshell || true
sleep 1
rm -f "$SOCK"
setsid nohup quickshell >/dev/null 2>&1 < /dev/null &
for _ in $(seq 1 30); do
  sleep 0.5
  if [[ -S "$SOCK" ]] && connect 2>/dev/null; then
    exit 0
  fi
done
echo "launcher socket still not found at $SOCK" >&2
exit 1
