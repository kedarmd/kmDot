#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SDDM_THEME_DIR="/usr/share/sddm/themes/kmd-quickshell"
OLD_SDDM_THEME_DIR="/usr/share/sddm/themes/kmd-hyprlock"

# Authenticate before changing anything, including deleting the previous theme.
sudo -v

ACTIVE_THEME="$(cat "$HOME/.cache/kmdot_theme" 2>/dev/null || printf tokyonight)"
"$REPO_DIR/theme-switcher/hooks/sddm.sh" "$ACTIVE_THEME"
sudo mkdir -p "$SDDM_THEME_DIR"
sudo install -Dm644 "$REPO_DIR/config/sddm/themes/kmd-quickshell/theme.conf" "$SDDM_THEME_DIR/theme.conf"
sudo install -Dm644 "$REPO_DIR/config/sddm/themes/kmd-quickshell/Main.qml" "$SDDM_THEME_DIR/Main.qml"
sudo install -Dm644 "$REPO_DIR/config/sddm/themes/kmd-quickshell/metadata.desktop" "$SDDM_THEME_DIR/metadata.desktop"
sudo ln -sfn /var/tmp/kmdot-sddm-theme.conf "$SDDM_THEME_DIR/theme.conf.user"
sudo install -Dm644 "$REPO_DIR/config/sddm/sddm.conf" /etc/sddm.conf.d/kmdot.conf

# /etc/sddm.conf loads AFTER conf.d and can override our theme with the old
# name. Preserve unrelated settings, but migrate its explicit theme selection.
if [ -f /etc/sddm.conf ]; then
  UPDATED_CONFIG="$(mktemp)"
  trap 'rm -f "$UPDATED_CONFIG"' EXIT
  sudo cat /etc/sddm.conf | awk '
    /^\[/ { in_theme = ($0 ~ /^\[Theme\][[:space:]]*$/) }
    in_theme && /^[[:space:]]*(Current|CurrentTheme)[[:space:]]*=/ {
      sub(/=.*/, "=kmd-quickshell")
    }
    { print }
  ' > "$UPDATED_CONFIG"
  if ! sudo cmp -s "$UPDATED_CONFIG" /etc/sddm.conf; then
    sudo cp -an /etc/sddm.conf /etc/sddm.conf.kmdot-backup
    sudo install -m644 "$UPDATED_CONFIG" /etc/sddm.conf
  fi
fi

sudo rm -rf "$OLD_SDDM_THEME_DIR"

if sudo systemctl enable sddm.service; then
  echo "SDDM enabled for the next boot."
else
  echo "Could not enable SDDM. Run manually: sudo systemctl enable sddm.service" >&2
fi

echo "kmDot SDDM greeter theme synced (takes effect on the next greeter start)."
