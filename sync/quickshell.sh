#!/usr/bin/env bash
set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
QUICKSHELL_CONFIG_DIR="$HOME/.config/quickshell"
KMDOT_QUICKSHELL_CONFIG_DIR="$HOME/.config/kmdot/quickshell"
KMDOT_CONFIG_DIR="$HOME/.config/kmdot"

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

# Build and validate the complete payload beside the deployed tree. Renaming
# within ~/.config/kmdot keeps promotion on one filesystem. The previous tree
# is retained as a timestamped rollback copy; a failed promotion restores it.
if [[ -e "$QUICKSHELL_CONFIG_DIR" && ! -L "$QUICKSHELL_CONFIG_DIR" ]]; then
  echo "ERROR: $QUICKSHELL_CONFIG_DIR is a real directory; refusing to replace it." >&2
  exit 1
fi
if [[ -L "$QUICKSHELL_CONFIG_DIR" ]] \
  && [[ "$(readlink -f "$QUICKSHELL_CONFIG_DIR" 2>/dev/null || true)" != "$KMDOT_QUICKSHELL_CONFIG_DIR" ]]; then
  echo "ERROR: $QUICKSHELL_CONFIG_DIR points somewhere unexpected; refusing to replace it." >&2
  exit 1
fi

exec 9>"$KMDOT_CONFIG_DIR/.quickshell-sync.lock"
if ! flock -n 9; then
  echo "ERROR: another Quickshell sync is already running." >&2
  exit 1
fi

DEPLOY_ID="$(date +%Y%m%dT%H%M%S)"
STAGE="$(mktemp -d "$KMDOT_CONFIG_DIR/.quickshell-stage.XXXXXX")"
BACKUP="$KMDOT_CONFIG_DIR/quickshell.backup.$DEPLOY_ID"
BACKUP_MOVED=0
DEPLOYED=0
cleanup_deploy() {
  result=$?
  if (( result != 0 && BACKUP_MOVED == 1 )); then
    rollback_ok=1
    if (( DEPLOYED == 1 )); then
      if ! mv -T -- "$KMDOT_QUICKSHELL_CONFIG_DIR" "$KMDOT_CONFIG_DIR/quickshell.failed.$DEPLOY_ID" 2>/dev/null; then
        rollback_ok=0
      fi
    fi
    if (( rollback_ok == 1 )) && mv -T -- "$BACKUP" "$KMDOT_QUICKSHELL_CONFIG_DIR" 2>/dev/null; then
      echo "Quickshell sync failed; previous configuration restored from $BACKUP." >&2
    else
      echo "ERROR: Quickshell sync failed and automatic rollback could not restore the previous configuration. Backup remains at $BACKUP; inspect $KMDOT_QUICKSHELL_CONFIG_DIR and the backup before recovery." >&2
    fi
  fi
  if [[ -n "${STAGE:-}" && -d "$STAGE" ]]; then rm -rf -- "$STAGE"; fi
  rm -f -- "$PALETTE_TEMP"
}
trap cleanup_deploy EXIT

cp -a "$REPO_DIR/config/quickshell/." "$STAGE/"
install -m644 "$PALETTE_TEMP" "$STAGE/Colors.qml"
[[ -s "$STAGE/shell.qml" && -s "$STAGE/Colors.qml" && -d "$STAGE/scripts" ]] || {
  echo "ERROR: staged Quickshell configuration is incomplete." >&2
  exit 1
}

# Repo files written by the editor default to 0644; scripts must be executable
# or systemd units / cron / etc. fail to spawn them (systemd-inhibit once
# exited status=1 because a spawned script wasn't +x).
chmod +x "$STAGE/scripts/"*.sh
# Glob-safe for .mjs (set -e would abort if the literal pattern never matches).
find "$STAGE/scripts" -maxdepth 1 -name '*.mjs' -exec chmod +x {} +
chmod +x "$STAGE/launcher/bin/"*

if [[ -e "$KMDOT_QUICKSHELL_CONFIG_DIR" || -L "$KMDOT_QUICKSHELL_CONFIG_DIR" ]]; then
  mv -T -- "$KMDOT_QUICKSHELL_CONFIG_DIR" "$BACKUP"
  BACKUP_MOVED=1
fi
mv -T -- "$STAGE" "$KMDOT_QUICKSHELL_CONFIG_DIR"
STAGE=""
DEPLOYED=1
if [[ ! -L "$QUICKSHELL_CONFIG_DIR" ]]; then
  link_tmp="$HOME/.config/.quickshell-link.$DEPLOY_ID"
  ln -s "$KMDOT_QUICKSHELL_CONFIG_DIR" "$link_tmp"
  mv -Tf -- "$link_tmp" "$QUICKSHELL_CONFIG_DIR"
fi

# One provider supervisor owns Handy/Hex startup. The app-managed login routes
# are disabled before the selected provider is started.
install -Dm644 "$REPO_DIR/config/systemd/user/dictation-provider.service" \
  "$HOME/.config/systemd/user/dictation-provider.service"
systemctl --user daemon-reload
"$KMDOT_QUICKSHELL_CONFIG_DIR/scripts/dictation-provider.sh" configure-autostart
systemctl --user enable dictation-provider.service
systemctl --user restart dictation-provider.service

if [ -n "${WAYLAND_DISPLAY:-}" ] && command -v wl-paste >/dev/null 2>&1; then
  "$KMDOT_QUICKSHELL_CONFIG_DIR/scripts/clipboard-daemon.sh" >/dev/null 2>&1 &
fi

trap - EXIT
rm -f -- "$PALETTE_TEMP"
echo "kmDot quickshell config synced. Previous config: ${BACKUP:-none}"
