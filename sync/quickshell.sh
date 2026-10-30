#!/usr/bin/env bash
set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
QUICKSHELL_CONFIG_DIR="$HOME/.config/quickshell"
KMDOT_QUICKSHELL_CONFIG_DIR="$HOME/.config/kmdot/quickshell"

# Resolve an explicitly selected theme before touching the deployed configuration.
THEME="${1:-$(cat "$HOME/.cache/kmdot_theme" 2>/dev/null || true)}"
if [[ ! "$THEME" =~ ^[a-z][a-z0-9_-]*$ ]] || [[ ! -f "$REPO_DIR/themes/$THEME/quickshell.conf" ]]; then
  echo "ERROR: Select a theme first, or run sync/quickshell.sh <theme>. No default palette is installed." >&2
  exit 1
fi
PALETTE_TEMP="$(mktemp)"
trap 'rm -f "$PALETTE_TEMP"' EXIT
"$REPO_DIR/theme-switcher/render-quickshell.sh" "$REPO_DIR/themes/$THEME/quickshell.conf" > "$PALETTE_TEMP"

# Retire only the standalone service installed by the oma-cast CachyOS port.
# Keep its checkout and original data for future upstream comparisons/rollback.
LEGACY_SERVICE="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/kay-cast.service"
if [[ -f "$LEGACY_SERVICE" ]] && grep -qx '# Managed by kay-cast' "$LEGACY_SERVICE"; then
  systemctl --user disable --now kay-cast.service
fi

# Import each legacy XDG directory once. Runtime files/symlinks are not data;
# never import the checkout link or overwrite kmDot's newer preferences/history.
for BASE in "${XDG_CONFIG_HOME:-$HOME/.config}" "${XDG_DATA_HOME:-$HOME/.local/share}" \
            "${XDG_CACHE_HOME:-$HOME/.cache}" "${XDG_STATE_HOME:-$HOME/.local/state}"; do
  LEGACY="$BASE/kay-cast"
  DEST="$BASE/kmdot-launcher"
  if [[ -d "$LEGACY" && ! -e "$DEST" && ! -L "$DEST" ]]; then
    IMPORT_STAGE="$(mktemp -d "$BASE/.kmdot-launcher-import.XXXXXX")"
    for ENTRY in "$LEGACY"/* "$LEGACY"/.[!.]* "$LEGACY"/..?*; do
      [[ -e "$ENTRY" || -L "$ENTRY" ]] || continue
      [[ "${ENTRY##*/}" == runtime ]] && continue
      if ! cp -a -- "$ENTRY" "$IMPORT_STAGE/"; then
        rm -rf -- "$IMPORT_STAGE"
        exit 1
      fi
    done
    mv -T -- "$IMPORT_STAGE" "$DEST"
    echo "Imported standalone launcher data into $DEST"
  fi
done
mkdir -p "$HOME/.config/kmdot"

rm -rf "$KMDOT_QUICKSHELL_CONFIG_DIR"
rm -rf "$QUICKSHELL_CONFIG_DIR"

cp -r "$REPO_DIR/config/quickshell" "$KMDOT_QUICKSHELL_CONFIG_DIR"
install -m644 "$PALETTE_TEMP" "$KMDOT_QUICKSHELL_CONFIG_DIR/Colors.qml"

# Repo files written by the editor default to 0644; scripts must be executable
# or systemd units / cron / etc. fail to spawn them (systemd-inhibit once
# exited status=1 because a spawned script wasn't +x).
chmod +x "$KMDOT_QUICKSHELL_CONFIG_DIR/scripts/"*.sh
# Glob-safe for .mjs (set -e would abort if the literal pattern never matches).
find "$KMDOT_QUICKSHELL_CONFIG_DIR/scripts" -maxdepth 1 -name '*.mjs' -exec chmod +x {} +
chmod +x "$KMDOT_QUICKSHELL_CONFIG_DIR/launcher/bin/"*

ln -sf "$KMDOT_QUICKSHELL_CONFIG_DIR" "$QUICKSHELL_CONFIG_DIR"

if [ -n "${WAYLAND_DISPLAY:-}" ] && command -v wl-paste >/dev/null 2>&1; then
  "$KMDOT_QUICKSHELL_CONFIG_DIR/scripts/clipboard-daemon.sh" >/dev/null 2>&1 &
fi

echo "kmDot quickshell config synced!!!"
