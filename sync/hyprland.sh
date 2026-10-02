#!/usr/bin/env bash
set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HYPRLAND_CONFIG_DIR="$HOME/.config/hypr"
KMDOT_HYPRLAND_CONFIG_DIR="$HOME/.config/kmdot/hyprland"

mkdir -p "$HOME/.config/kmdot"

rm -rf "$KMDOT_HYPRLAND_CONFIG_DIR"
rm -rf "$HYPRLAND_CONFIG_DIR"

cp -r "$REPO_DIR/config/hyprland" "$KMDOT_HYPRLAND_CONFIG_DIR"

ln -sf "$KMDOT_HYPRLAND_CONFIG_DIR" "$HYPRLAND_CONFIG_DIR"

# Display settings are written at runtime by the quickshell DisplayState
# singleton (~/.config/kmdot/display-settings.lua, consumed by
# hyprland/monitors.lua). Link once here so the require() resolves even
# before the first persist; dangling until then is fine (pcall fallback).
ln -sf "$HOME/.config/kmdot/display-settings.lua" "$KMDOT_HYPRLAND_CONFIG_DIR/display-settings.lua"

WAYLAND_SESSIONS_DIR="$HOME/.local/share/wayland-sessions"
mkdir -p "$WAYLAND_SESSIONS_DIR"
cat > "$WAYLAND_SESSIONS_DIR/hyprland.desktop" <<EOF
[Desktop Entry]
Name=Hyprland
Comment=An intelligent dynamic tiling Wayland compositor
Exec=/usr/bin/env HYPRLAND_CONFIG=$HOME/.config/kmdot/hyprland/hyprland.lua /usr/bin/start-hyprland
Type=Application
DesktopNames=Hyprland
Keywords=tiling;wayland;compositor;
EOF

# try-restart is a no-op (exit 0) when hypridle isn't running yet, so this
# is safe on a fresh boot outside a Hyprland session under set -e.
if systemctl --user show-environment >/dev/null 2>&1; then
  systemctl --user try-restart hypridle.service
else
  echo "Skipping hypridle restart (no systemd user bus available)."
fi

echo "kmDot hyprland config synced!!!"
