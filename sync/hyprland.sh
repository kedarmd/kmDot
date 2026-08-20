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

systemctl --user restart hypridle.service

echo "kmDot hyprland config synced!!!"
