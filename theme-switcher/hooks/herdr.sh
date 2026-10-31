#!/usr/bin/env bash

# Exit on Error
set -e

CONFIG_FILE="$HOME/.config/herdr/config.toml"
THEME="$1"
COLORSCHEME_FILE="$HOME/.config/kmdot/themes/$THEME/herdr.conf"

if [ ! -f "$COLORSCHEME_FILE" ]; then
  echo "ERROR: Theme '$THEME' does not exist for herdr."
  exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
  echo "ERROR: Herdr config file not found: $CONFIG_FILE"
  echo "       Run ./sync/herdr.sh first, then launch herdr once."
  exit 1
fi

# Herdr read-modify-writes its own config (onboarding, Settings) and may lay
# sections out in any order, so locate the theme region dynamically: from the
# first [theme]*/[theme.custom]* header (plus any comment lines sitting right
# above it, which belong to the snippet and must not accumulate across theme
# switches) to the next non-theme section header or EOF. Only that region is
# replaced — [keys]/[ui] etc. stay untouched.
read -r REGION_START REGION_END < <(awk '
  { lines[NR] = $0 }
  END {
    h = 0
    for (i = 1; i <= NR; i++)
      if (lines[i] ~ /^\[theme(\.[^]]*)?\][ \t]*$/) { h = i; break }
    if (!h) { print "0 0"; exit }

    s = h
    while (s > 1 && lines[s-1] ~ /^[ \t]*(#|$)/) s--

    e = NR
    for (i = h + 1; i <= NR; i++) {
      if (lines[i] ~ /^\[[^]]*\][ \t]*$/ && lines[i] !~ /^\[theme(\.[^]]*)?\]/) {
        e = i - 1
        break
      }
    }
    printf "%d %d\n", s, e
  }
' "$CONFIG_FILE")

TMP_FILE="${CONFIG_FILE}.swt"

if [ "$REGION_START" -gt 0 ]; then
  {
    head -n $((REGION_START - 1)) "$CONFIG_FILE"
    awk '1' "$COLORSCHEME_FILE"   # verbatim snippet; awk '1' guarantees a trailing newline
    tail -n "+$((REGION_END + 1))" "$CONFIG_FILE"
  } > "$TMP_FILE"
else
  {
    cat "$CONFIG_FILE"
    echo ""
    awk '1' "$COLORSCHEME_FILE"
  } > "$TMP_FILE"
fi

mv "$TMP_FILE" "$CONFIG_FILE"

# Restart-free reload: not file-watched, so poke the running server. No
# server/binary present is not an error — next launch reads the file.
RELOAD_MSG="applies on next herdr launch"
if command -v herdr >/dev/null 2>&1 && herdr server reload-config >/dev/null 2>&1; then
  RELOAD_MSG="live server reloaded"
fi

THEME_VALUE="$(grep -m1 '^name[ \t]*=' "$COLORSCHEME_FILE" | sed 's/^name[ \t]*=[ \t]*//' | tr -d '"')"

echo "✓ Herdr theme updated to: ${THEME_VALUE:-$THEME} ($RELOAD_MSG)"
