#!/usr/bin/env bash

# Exit on Error
set -e

CONFIG_FILE="$HOME/.config/zed/settings.json"
THEME="$1"
COLORSCHEME_FILE="$HOME/.config/kmdot/themes/$THEME/zed.conf"

if [ ! -f "$COLORSCHEME_FILE" ]; then
  echo "ERROR: Theme '$THEME' does not exist for zed."
  exit 1
fi

THEME_VALUE=$(grep "^theme" "$COLORSCHEME_FILE" | head -1 | sed 's/^theme\s*=\s*//' | tr -d '"')

if [ ! -f "$CONFIG_FILE" ]; then
  echo "ERROR: Zed settings file not found: $CONFIG_FILE"
  exit 1
fi

TMP_FILE="${CONFIG_FILE}.swt"

# Rewrite only the top-level "theme" key as a scalar value, leaving every other
# key (icon_theme, comments, keymap, ...) untouched. The result is written via
# `cat >` (truncate in place) so the file keeps its inode and Zed's settings
# watcher keeps hot-reloading it live.
awk -v target="$THEME_VALUE" '
  {
    L[NR] = $0
    n++
    if (!theme_idx && $0 ~ /^[ \t]*"theme"[ \t]*:/) {
      theme_idx = NR
      rest = $0
      sub(/^[ \t]*"theme"[ \t]*:[ \t]*/, "", rest)
      theme_is_object = (rest !~ /^"/)
    }
  }
  END {
    if (theme_idx) {
      line = L[theme_idx]
      indent = ""
      if (match(line, /^[ \t]*/)) indent = substr(line, 1, RLENGTH)
      if (theme_is_object) {
        depth = 0
        s = L[theme_idx]
        sub(/^[^:]*:[ \t]*/, "", s)
        depth += gsub(/\{/, "{", s) - gsub(/\}/, "}", s)
        end = theme_idx
        while (depth > 0 && end < n) {
          end++
          t = L[end]
          depth += gsub(/\{/, "{", t) - gsub(/\}/, "}", t)
        }
        for (i = 1; i <= n; i++) {
          if (i == theme_idx) print indent "\"theme\": \"" target "\","
          else if (i > theme_idx && i <= end) {}
          else print L[i]
        }
      } else {
        t = L[theme_idx]
        sub(/"theme"[ \t]*:[ \t]*"[^"]*"/, "\"theme\": \"" target "\"", t)
        for (i = 1; i <= n; i++) print (i == theme_idx ? t : L[i])
      }
    } else {
      for (i = 1; i <= n; i++) {
        if (!inserted && L[i] ~ /^[ \t]*}/) { print "  \"theme\": \"" target "\","; inserted = 1 }
        print L[i]
      }
    }
  }
' "$CONFIG_FILE" > "$TMP_FILE"

cat "$TMP_FILE" > "$CONFIG_FILE"
rm -f "$TMP_FILE"
touch "$CONFIG_FILE"

echo "✓ Zed theme updated to: $THEME_VALUE"