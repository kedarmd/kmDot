#!/usr/bin/env bash
set -euo pipefail

# Display mode switching for kmDot Display module.
# Usage: display-mode.sh <extend|mirror|external> [--position left|right]
#
# extend:   both outputs on, side-by-side (restores saved or default positions)
# mirror:   secondary mirrors primary
# external: disable internal, external only
# --position: specify external monitor position relative to internal (default: right)

MODE="${1:-extend}"
shift || true

# Auto-detect primary (laptop) monitor - look for internal display
PRIMARY=$(hyprctl monitors all -j 2>/dev/null | jq -r '.[] | select(.name | startswith("eDP")) | .name' | head -1)
if [ -z "$PRIMARY" ]; then
  PRIMARY="eDP-1"
fi

# Parse remaining args
POSITION="right"
while [ $# -gt 0 ]; do
  case "$1" in
    --position)
      shift
      POSITION="${1:-right}"
      shift
      ;;
    left|right)
      POSITION="$1"
      shift
      ;;
    *)
      shift
      ;;
  esac
done

STATE_DIR="$HOME/.cache/kmdot"
POSITIONS_FILE="$STATE_DIR/display-positions.json"

# Ensure state directory exists
mkdir -p "$STATE_DIR"

# Get monitors JSON including disabled ones
ALL_MONITORS_JSON=$(hyprctl monitors all -j 2>/dev/null || echo "[]")
ACTIVE_MONITORS_JSON=$(hyprctl monitors -j 2>/dev/null || echo "[]")

# Get rule from JSON (works with both active and all monitors)
get_hl_rule_from_json() {
  local json="$1"
  local name="$2"
  echo "$json" | jq -r --arg n "$name" \
    '.[] | select(.name == $n) | "{ output = \"" + .name + "\", mode = \"" + (.width | tostring) + "x" + (.height | tostring) + "@" + (.refreshRate | floor | tostring) + "\", position = \"" + (.x | tostring) + "x" + (.y | tostring) + "\", scale = " + (.scale // 1 | tostring) + " }"' 2>/dev/null || echo ""
}

# Get rule for a monitor (active first, then all)
get_hl_rule() {
  local name="$1"
  local rule=$(get_hl_rule_from_json "$ACTIVE_MONITORS_JSON" "$name")
  if [ -z "$rule" ]; then
    rule=$(get_hl_rule_from_json "$ALL_MONITORS_JSON" "$name")
  fi
  echo "$rule"
}

# Get secondary monitor name
get_second() {
  echo "$ACTIVE_MONITORS_JSON" | jq -r --arg p "$PRIMARY" \
    '.[] | select(.name != $p) | .name' 2>/dev/null | head -1 || echo ""
}

SECONDARY=$(get_second)

apply_monitor() {
  local rule="$1"
  hyprctl eval "hl.monitor($rule)"
}

# Save current positions before mode switch
save_positions() {
  local primary_rule=$(get_hl_rule "$PRIMARY")
  local secondary_rule=""
  if [ -n "$SECONDARY" ]; then
    secondary_rule=$(get_hl_rule "$SECONDARY")
  fi
  
  jq -n \
    --arg primary "$PRIMARY" \
    --arg primary_rule "$primary_rule" \
    --arg secondary "$SECONDARY" \
    --arg secondary_rule "$secondary_rule" \
    '{primary: $primary, primary_rule: $primary_rule, secondary: $secondary, secondary_rule: $secondary_rule}' \
    > "$POSITIONS_FILE"
}

# Load saved positions or use defaults, respecting POSITION flag
load_positions() {
  # Get monitor widths
  local internal_width=1920
  local external_width=1920
  
  local internal_info=$(echo "$ALL_MONITORS_JSON" | jq -r --arg n "$PRIMARY" '.[] | select(.name == $n) | .width')
  local external_info=""
  if [ -n "$SECONDARY" ]; then
    external_info=$(echo "$ALL_MONITORS_JSON" | jq -r --arg n "$SECONDARY" '.[] | select(.name == $n) | .width')
  fi
  
  [ -n "$internal_info" ] && internal_width=$internal_info
  [ -n "$external_info" ] && external_width=$external_info
  
  # Generate positions based on POSITION flag
  if [ "$POSITION" = "right" ]; then
    # External on right: internal at 0x0, external at internal_width x 0
    echo "{\"primary\":\"$PRIMARY\",\"primary_rule\":\"{ output = \\\"$PRIMARY\\\", mode = \\\"${internal_width}x1080@60\\\", position = \\\"0x0\\\", scale = 1 }\",\"secondary\":\"$SECONDARY\",\"secondary_rule\":\"{ output = \\\"$SECONDARY\\\", mode = \\\"${external_width}x1080@60\\\", position = \\\"${internal_width}x0\\\", scale = 1 }\"}"
  else
    # External on left: external at 0x0, internal at external_width x 0
    echo "{\"primary\":\"$PRIMARY\",\"primary_rule\":\"{ output = \\\"$PRIMARY\\\", mode = \\\"${internal_width}x1080@60\\\", position = \\\"${external_width}x0\\\", scale = 1 }\",\"secondary\":\"$SECONDARY\",\"secondary_rule\":\"{ output = \\\"$SECONDARY\\\", mode = \\\"${external_width}x1080@60\\\", position = \\\"0x0\\\", scale = 1 }\"}"
  fi
}

case "$MODE" in
  extend)
    # Load positions to restore (do NOT save here - we want to restore the LAST good state)
    POSITIONS=$(load_positions)
    PRIMARY_RULE=$(echo "$POSITIONS" | jq -r '.primary_rule')
    SECONDARY_RULE=$(echo "$POSITIONS" | jq -r '.secondary_rule')
    
    # Re-enable primary (add disabled=false to ensure it comes back)
    if [ -n "$PRIMARY_RULE" ]; then
      ENABLED_PRIMARY=$(echo "$PRIMARY_RULE" | sed 's/}/, disabled = false }/')
      apply_monitor "$ENABLED_PRIMARY"
    fi
    
    # Re-enable secondary if it exists
    if [ -n "$SECONDARY" ] && [ -n "$SECONDARY_RULE" ]; then
      ENABLED_SECONDARY=$(echo "$SECONDARY_RULE" | sed 's/}/, disabled = false }/')
      apply_monitor "$ENABLED_SECONDARY"
    fi
    ;;

  mirror)
    # Save positions before mirroring
    save_positions
    
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
    # Save positions before disabling internal
    save_positions
    
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
