#!/usr/bin/env bash
# Toggle kmDot's integrated launcher with its Applications filter selected.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$DIR/toggle.sh" kmdot-launcher
