#!/usr/bin/env bash
set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HERDR_APP_CONFIG_DIR="$HOME/.config/herdr-app"
KMDOT_HERDR_APP_CONFIG_DIR="$HOME/.config/kmdot/herdr-app"

mkdir -p "$HOME/.config/kmdot"

# Deployed mirror, like the other apps' ~/.config/kmdot/<app> copies.
rm -rf "$KMDOT_HERDR_APP_CONFIG_DIR"
cp -r "$REPO_DIR/config/herdr-app" "$KMDOT_HERDR_APP_CONFIG_DIR"

# ~/.config/herdr-app is also Herdr App's live home: herdr-app.sock, data/,
# frame/, installed.json, seen.json, window state and the generated
# gpui-kit.d.ts / herdr.d.ts / jsconfig.json files live there and must survive.
# Deploy the kmDot-managed files over the directory in place — never replace
# the directory itself.
mkdir -p "$HERDR_APP_CONFIG_DIR"
cp -r "$KMDOT_HERDR_APP_CONFIG_DIR/." "$HERDR_APP_CONFIG_DIR/"

# The active theme file is generated, not tracked: theme-switcher/hooks/herdr-app.sh
# rewrites it on every switch. Seed it here too so a fresh sync (or a sync before
# the first theme switch) leaves the app themed with the selected kmDot theme.
SELECTED_THEME="$(cat "$HOME/.cache/kmdot_theme" 2>/dev/null || true)"
[ -n "$SELECTED_THEME" ] || SELECTED_THEME="tokyonight"
THEME_SOURCE="$REPO_DIR/themes/$SELECTED_THEME/herdr-app.json"
[ -f "$THEME_SOURCE" ] || THEME_SOURCE="$REPO_DIR/themes/tokyonight/herdr-app.json"
mkdir -p "$HERDR_APP_CONFIG_DIR/themes"
cp "$THEME_SOURCE" "$HERDR_APP_CONFIG_DIR/themes/kmdot-active.json"

# shared.json holds the shown layout ("layout"), not settings.json. Point it at
# the kmDot layout without discarding the app's other state: use the live
# window when it is open, otherwise edit the file the next launch reads.
if command -v herdr-app >/dev/null 2>&1 && herdr-app status >/dev/null 2>&1; then
  herdr-app do layout.switch --name kmdot >/dev/null 2>&1 || true
elif command -v node >/dev/null 2>&1; then
  node -e '
    const fs = require("fs");
    const path = process.argv[1];
    let state = {};
    try { state = JSON.parse(fs.readFileSync(path, "utf8")); } catch {}
    if (state.layout !== "kmdot") {
      state.layout = "kmdot";
      fs.writeFileSync(path, JSON.stringify(state));
    }
  ' "$HERDR_APP_CONFIG_DIR/shared.json"
fi

# Herdr App reloads its config files live; no restart needed.
echo "kmDot herdr-app config synced!!!"
