#!/usr/bin/env bash
# Toggle a kmDot quickshell launcher by socket name (kmdot-launcher, kmdot-system, ...).
# A missing or stale socket is reported to the user. Popup interactions must never
# restart the complete desktop shell: that can destroy notification/lock state and
# conceal the actual initialization failure.
set -euo pipefail

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

if [[ -S "$SOCK" ]]; then
  message="The launcher socket $SOCK exists but is not accepting connections. Check the Quickshell log."
else
  message="The launcher socket $SOCK is missing. Check that Quickshell started successfully."
fi
printf 'kmDot: %s\n' "$message" >&2
notify-send --urgency=critical "kmDot launcher unavailable" "$message" 2>/dev/null || true
exit 1
