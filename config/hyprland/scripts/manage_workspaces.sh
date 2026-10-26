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

# External-only mode disables the laptop panel. If that output disappears
# (including a dock/monitor power cut), restore the internal panel immediately
# so the session remains usable. The display-settings.lua override can still
# request external-only on the next compositor start; this runtime guard heals
# it again whenever the external connector is absent.
recover_internal_display() {
  local monitors internal_disabled external_active internal_mode internal_scale connector_status
  local drm_status_file drm_status_seen=false
  monitors=$(hyprctl monitors all -j 2>/dev/null) || return
  internal_disabled=$(jq -r --arg name "$LAPTOP" '[.[] | select(.name == $name and .disabled == true)] | length' <<< "$monitors")
  [[ "$internal_disabled" == 1 ]] || return
  external_active=$(jq -r --arg name "$EXTERNAL" '[.[] | select(.name == $name and .disabled != true)] | length' <<< "$monitors")

  # A powered-off display may leave the compositor's last output entry alive.
  # DRM connector status reflects the physical link and catches that case.
  connector_status=""
  for drm_status_file in /sys/class/drm/card*-"$EXTERNAL"/status; do
    [[ -r "$drm_status_file" ]] || continue
    drm_status_seen=true
    connector_status=$(<"$drm_status_file")
    [[ "$connector_status" == connected ]] && break
  done
  if [[ "$drm_status_seen" == true ]]; then
    [[ "$connector_status" == connected ]] || external_active=0
  fi
  [[ "$external_active" == 0 ]] || return

  internal_mode=$(jq -r --arg name "$LAPTOP" 'first(.[] | select(.name == $name) | .availableModes[0] // empty)' <<< "$monitors")
  [[ -n "$internal_mode" ]] || internal_mode="1920x1080@60Hz"
  internal_mode=${internal_mode%Hz}
  internal_scale=$(jq -r --arg name "$LAPTOP" 'first(.[] | select(.name == $name) | .scale // 1)' <<< "$monitors")
  hyprctl eval "hl.monitor({ output = \"$LAPTOP\", mode = \"$internal_mode\", position = \"0x0\", scale = $internal_scale, disabled = false })" >/dev/null 2>&1
}

# Monitor hotplug can happen after the Hyprland startup hook. Reconcile only
# when the connected-output set changes so we do not move workspaces on every
# poll. Persistent rules retain empty workspaces for the quickshell bar.
LAST_ACTIVE=""
while sleep 1; do
  recover_internal_display
  ACTIVE=$(hyprctl monitors 2>/dev/null | awk '/^Monitor / {print $2}')
  [[ -n "$ACTIVE" ]] || continue
  if [[ "$ACTIVE" != "$LAST_ACTIVE" ]]; then
    apply_layout "$ACTIVE"
    LAST_ACTIVE="$ACTIVE"
  fi
done

