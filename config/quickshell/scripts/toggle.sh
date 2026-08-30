#!/usr/bin/env bash
# Toggle a kmDot quickshell launcher by socket name (kmdot-launcher, kmdot-system, ...).
# Self-heals: if the socket is missing (quickshell live-reloaded after a theme switch
# and unlinked it, or quickshell is not running), restarts quickshell and retries.
set -euo pipefail
eval "$(mise activate bash)" 2>/dev/null || true

SOCK_NAME="${1:?usage: toggle.sh <sockname>}"
SOCK="${XDG_RUNTIME_DIR:-/tmp}/${SOCK_NAME}.sock"

connect() {
  node -e '
    const net = require("net");
    const sock = net.connect(process.argv[1]);
    sock.setTimeout(3000, () => { sock.destroy(); process.exit(1); });
    sock.on("connect", () => process.exit(0));
    sock.on("error", () => process.exit(1));
  ' "$SOCK"
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
