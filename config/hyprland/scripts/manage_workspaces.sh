#!/usr/bin/env bash

LAPTOP="eDP-1"
EXTERNAL="HDMI-A-1"

assign_workspace() {
  # Workspace move is a no-op until the workspace exists. Focus creates it;
  # the persistent rules in monitors.lua keep it alive after it is moved.
  hyprctl eval "hl.dispatch(hl.dsp.focus({ workspace = \"$1\" }))" >/dev/null
  hyprctl dispatch "hl.dsp.workspace.move({ workspace = \"$1\", monitor = \"$2\" })" >/dev/null
}

apply_layout() {
  local active_workspace
  active_workspace=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id // empty')
  if awk -v monitor="$EXTERNAL" '$0 == monitor {found=1} END {exit !found}' <<< "$1"; then
    # External connected: 1–4 go external; 5 stays on the laptop.
    for workspace in {1..4}; do
      assign_workspace "$workspace" "$EXTERNAL"
    done
    assign_workspace 5 "$LAPTOP"
  else
    # Without the external display, keep all workspaces on the internal panel.
    for workspace in {1..5}; do
      assign_workspace "$workspace" "$LAPTOP"
    done
  fi
  [[ -n "$active_workspace" ]] && hyprctl eval "hl.dispatch(hl.dsp.focus({ workspace = \"$active_workspace\" }))" >/dev/null
}

# Monitor hotplug can happen after the Hyprland startup hook. Reconcile only
# when the connected-output set changes so we do not move workspaces on every
# poll. Persistent rules retain empty workspaces for the quickshell bar.
LAST_ACTIVE=""
while sleep 1; do
  ACTIVE=$(hyprctl monitors 2>/dev/null | awk '/^Monitor / {print $2}')
  [[ -n "$ACTIVE" ]] || continue
  if [[ "$ACTIVE" != "$LAST_ACTIVE" ]]; then
    apply_layout "$ACTIVE"
    LAST_ACTIVE="$ACTIVE"
  fi
done

