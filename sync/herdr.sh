#!/usr/bin/env bash
set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HERDR_CONFIG_DIR="$HOME/.config/herdr"
KMDOT_HERDR_CONFIG_DIR="$HOME/.config/kmdot/herdr"

mkdir -p "$HOME/.config/kmdot"

# ~/.config/herdr doubles as herdr's runtime directory — the server/client
# sockets, session.json, session-snapshots and logs all live there — so the
# stock "rm -rf, copy, symlink" pattern would kill a running server's socket
# and wipe session state. Deploy the repo-managed files in place instead and
# leave everything herdr owns alone.
mkdir -p "$KMDOT_HERDR_CONFIG_DIR"

# First sync over an existing herdr install (real directory, no symlink yet):
# move herdr's runtime state into the kmdot copy so nothing is lost, then
# swap the directory for the symlink.
if [ -d "$HERDR_CONFIG_DIR" ] && [ ! -L "$HERDR_CONFIG_DIR" ]; then
  # A live server holds its control socket in this directory. The swap
  # replaces it, so the running server (panes and all) becomes unreachable
  # until it is restarted — flag it instead of silently orphaning it.
  if find "$HERDR_CONFIG_DIR" -type s -print -quit 2>/dev/null | grep -q .; then
    echo "NOTE: herdr server is running — this first sync replaces its control"
    echo "      socket with the kmdot symlink. Panes keep running, but the old"
    echo "      server becomes unreachable; cleanest is 'herdr server stop'"
    echo "      before syncing (saves the session, closes panes), then re-run."
    echo "      Layout restores from session.json either way."
  fi
  cp -rn "$HERDR_CONFIG_DIR/." "$KMDOT_HERDR_CONFIG_DIR/" 2>/dev/null || true
  # cp recreates copied socket files as dead sockets — drop them so a
  # fresh server can bind cleanly after the swap.
  find "$KMDOT_HERDR_CONFIG_DIR" -type s -delete 2>/dev/null || true
  rm -rf "$HERDR_CONFIG_DIR"
fi

# Everything except config.toml deploys wholesale (scripts/ and friends).
for entry in "$REPO_DIR/config/herdr"/*; do
  [ "$(basename "$entry")" = "config.toml" ] && continue
  cp -r "$entry" "$KMDOT_HERDR_CONFIG_DIR/"
done

# config.toml is shared with herdr itself: onboarding, ui.toast and
# theme.custom keys are herdr's own writes, so a wholesale copy would reset
# them on every sync. First deploy installs the repo version; later syncs
# only upsert the kmDot-owned [ui] keys in place. The [theme] region stays
# owned by theme-switcher/hooks/herdr.sh.
CONFIG_FILE="$KMDOT_HERDR_CONFIG_DIR/config.toml"
if [ ! -f "$CONFIG_FILE" ]; then
  cp "$REPO_DIR/config/herdr/config.toml" "$CONFIG_FILE"
else
  TMP_FILE="${CONFIG_FILE}.swt"
  awk '
    # First pass (FNR == NR): collect the repo [ui] section''s key lines.
    FNR == NR {
      if ($0 ~ /^[ \t]*\[[^]]*\][ \t]*$/) { in_ui = ($0 ~ /^[ \t]*\[ui\][ \t]*$/); next }
      if (in_ui && $0 ~ /^[ \t]*[A-Za-z_][A-Za-z0-9_]*[ \t]*=/) {
        key = $0; sub(/[ \t]*=.*/, "", key); gsub(/[ \t]/, "", key)
        managed[key] = $0; num_keys++
      }
      next
    }
    # Second pass: the live config.
    { n++; lines[n] = $0 }
    END {
      ui_header = 0; in_ui = 0
      for (i = 1; i <= n; i++) {
        if (lines[i] ~ /^[ \t]*\[[^]]*\][ \t]*$/) {
          in_ui = (lines[i] ~ /^[ \t]*\[ui\][ \t]*$/)
          if (in_ui) ui_header = i
          continue
        }
        if (in_ui) {
          key = lines[i]; sub(/[ \t]*=.*/, "", key); gsub(/[ \t]/, "", key)
          if (key in managed) { replace_at[i] = key; present[key] = 1 }
        }
      }
      for (i = 1; i <= n; i++) {
        if (i in replace_at) { print managed[replace_at[i]]; continue }
        print lines[i]
        if (i == ui_header)
          for (key in managed) if (!(key in present)) print managed[key]
      }
      if (!ui_header && num_keys > 0) {
        if (n > 0 && lines[n] !~ /^[ \t]*$/) print ""
        print "[ui]"
        for (key in managed) print managed[key]
      }
    }
  ' "$REPO_DIR/config/herdr/config.toml" "$CONFIG_FILE" > "$TMP_FILE"
  mv "$TMP_FILE" "$CONFIG_FILE"
fi

ln -sfn "$KMDOT_HERDR_CONFIG_DIR" "$HERDR_CONFIG_DIR"

# Link the tab-titles plugin so its event hooks (tab
# created/closed/moved → renumber.mjs) fire. Re-linking is
# refused over an existing link, so unlink first; no server or
# binary present is not an error — the next launch links it.
PLUGIN_DIR="$KMDOT_HERDR_CONFIG_DIR/plugins/kmdot-tab-titles"
if command -v herdr >/dev/null 2>&1 && [ -d "$PLUGIN_DIR" ]; then
  herdr plugin unlink kmdot.tab-titles >/dev/null 2>&1 || true
  herdr plugin link "$PLUGIN_DIR" >/dev/null || true
fi

echo "kmDot herdr config synced!!!"
