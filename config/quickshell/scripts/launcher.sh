#!/usr/bin/env bash
# Toggle the quickshell app launcher (alias for toggle.sh kmdot-launcher).
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$DIR/toggle.sh" kmdot-launcher
