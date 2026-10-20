#!/usr/bin/env bash
# Preview the same strictly validated palette used by the renderer.
set -euo pipefail
THEME_DIR="$HOME/.config/kmdot/themes"
RENDER="$HOME/.config/kmdot/theme-switcher/render-quickshell.sh"
ACTIVE="$(cat "$HOME/.cache/kmdot_theme" 2>/dev/null || true)"
while IFS= read -r theme; do
  [[ "$theme" =~ ^[a-z][a-z0-9_-]*$ ]] || continue
  palette="$("$RENDER" "$THEME_DIR/$theme/quickshell.conf" --json)"
  active=false
  [[ "$theme" != "$ACTIVE" ]] || active=true
  printf '{"theme":"%s","active":%s,"palette":%s}\n' "$theme" "$active" "$palette"
done < <(find "$THEME_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
