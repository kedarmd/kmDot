#!/usr/bin/env bash

LAPTOP="eDP-1"
EXTERNAL="HDMI-A-1"

# This is intentionally a startup-only decision. Wait briefly for Hyprland to
# finish bringing up the configured outputs before taking the snapshot.
for _ in {1..20}; do
  ACTIVE=$(hyprctl monitors 2>/dev/null | awk '/^Monitor / {print $2}')
  [[ -n "$ACTIVE" ]] && break
  sleep 0.25
done

assign_workspace() {
  # Hyprland 0.55+ uses Lua for workspace rules and dispatchers.
  hyprctl eval "hl.workspace_rule({ workspace = \"$1\", monitor = \"$2\" })" >/dev/null
  hyprctl dispatch "hl.dsp.workspace.move({ workspace = \"$1\", monitor = \"$2\" })" >/dev/null
}

if awk -v monitor="$EXTERNAL" '$0 == monitor {found=1} END {exit !found}' <<< "$ACTIVE"; then
  # External present at startup: 1–4 go external; 5 stays on the laptop.
  assign_workspace 1 "$EXTERNAL"
  assign_workspace 2 "$EXTERNAL"
  assign_workspace 3 "$EXTERNAL"
  assign_workspace 4 "$EXTERNAL"
  assign_workspace 5 "$LAPTOP"
else
  # No external at startup: all five workspaces stay on the laptop.
  for workspace in {1..5}; do
    assign_workspace "$workspace" "$LAPTOP"
  done
fi

