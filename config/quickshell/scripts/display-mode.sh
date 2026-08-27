#!/usr/bin/env bash
set -euo pipefail

# Display mode switching for kmDot Display module.
# Usage: display-mode.sh <extend|mirror|external> [primary_output]
#
# extend:   both outputs on, side-by-side (re-specifies full rules)
# mirror:   secondary mirrors primary (requires primary output name)
# external: disable internal, external only

MODE="${1:-extend}"
PRIMARY="${2:-eDP-1}"

MONITORS_JSON=$(hyprctl monitors -j 2>/dev/null || echo "[]")

get_hl_rule() {
  local name="$1"
  echo "$MONITORS_JSON" | jq -r --arg n "$name" \
    '.[] | select(.name == $n) | "{ output = \"" + .name + "\", mode = \"" + (.width | tostring) + "x" + (.height | tostring) + "@" + (.refreshRate | floor | tostring) + "\", position = \"" + (.x | tostring) + "x" + (.y | tostring) + "\", scale = " + (.scale // 1 | tostring) + " }"' 2>/dev/null || echo ""
}

get_second() {
  echo "$MONITORS_JSON" | jq -r --arg p "$PRIMARY" \
    '.[] | select(.name != $p) | .name' 2>/dev/null | head -1 || echo ""
}

SECONDARY=$(get_second)

apply_monitor() {
  local rule="$1"
  hyprctl eval "hl.monitor($rule)"
}

case "$MODE" in
  extend)
    PRIMARY_RULE=$(get_hl_rule "$PRIMARY")
    if [ -n "$SECONDARY" ]; then
      SECONDARY_RULE=$(get_hl_rule "$SECONDARY")
      if [ -n "$PRIMARY_RULE" ]; then
        apply_monitor "$PRIMARY_RULE"
      fi
      if [ -n "$SECONDARY_RULE" ]; then
        apply_monitor "$SECONDARY_RULE"
      fi
    fi
    ;;

  mirror)
    if [ -z "$SECONDARY" ]; then
      echo "No secondary display found to mirror" >&2
      exit 1
    fi
    PRIMARY_RULE=$(get_hl_rule "$PRIMARY")
    if [ -n "$PRIMARY_RULE" ]; then
      apply_monitor "$PRIMARY_RULE"
    fi
    SECONDARY_RULE=$(get_hl_rule "$SECONDARY")
    if [ -n "$SECONDARY_RULE" ]; then
      MIRRORED=$(echo "$SECONDARY_RULE" | sed "s/ }$/, mirror = \"$PRIMARY\" }/")
      apply_monitor "$MIRRORED"
    fi
    ;;

  external)
    if [ -z "$SECONDARY" ]; then
      echo "No external display found" >&2
      exit 1
    fi
    hyprctl eval "hl.monitor({ output = \"$PRIMARY\", disabled = true })"
    sleep 0.5
    SECONDARY_RULE=$(get_hl_rule "$SECONDARY")
    if [ -n "$SECONDARY_RULE" ]; then
      REPOSITIONED=$(echo "$SECONDARY_RULE" | sed 's/position = "[^"]*"/position = "0x0"/')
      apply_monitor "$REPOSITIONED"
    fi
    ;;

  *)
    echo "Unknown mode: $MODE (use extend, mirror, or external)" >&2
    exit 1
    ;;
esac
