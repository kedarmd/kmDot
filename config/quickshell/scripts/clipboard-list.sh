#!/usr/bin/env bash
# Prints clipboard history for the Quickshell launcher.
# Output: hash<TAB>type<TAB>epoch<TAB>snippet<TAB>preview-path
set -euo pipefail

CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/kmdot/clipboard"
INDEX="$CACHE/index"
TEXT_DIR="$CACHE/text"
IMG_DIR="$CACHE/img"
THUMB_DIR="$CACHE/thumb"
TTL=86400 # 1 day

mkdir -p "$TEXT_DIR" "$IMG_DIR" "$THUMB_DIR"

# Take the same lock as clipboard-capture.sh: this script rewrites the index
# and GCs payloads, so it must not run concurrently with a capture.
exec 9>"$CACHE/.lock"
flock 9

touch "$INDEX"

NOW="$(date +%s)"
awk -F'\t' -v now="$NOW" -v ttl="$TTL" 'NF >= 4 && (now - $3) <= ttl' "$INDEX" > "$INDEX.tmp" && mv "$INDEX.tmp" "$INDEX"

awk -F'\t' '{print $1}' "$INDEX" > "$CACHE/.live-hashes"
for f in "$TEXT_DIR"/* "$IMG_DIR"/*.png "$THUMB_DIR"/*.png; do
  [ -e "$f" ] || continue
  h="$(basename "$f" .png)"
  if ! grep -qxF "$h" "$CACHE/.live-hashes"; then
    rm -f "$f"
  fi
done
rm -f "$CACHE/.live-hashes"

human_size() {
  local bytes="$1"
  if [ "$bytes" -ge 1048576 ]; then
    printf '%s MB' "$((bytes / 1048576))"
  elif [ "$bytes" -ge 1024 ]; then
    printf '%s KB' "$((bytes / 1024))"
  else
    printf '%s B' "$bytes"
  fi
}

while IFS=$'\t' read -r h type epoch snippet; do
  [ -n "$h" ] || continue
  preview=""
  if [ "$type" = "img" ]; then
    size="$(stat -c %s "$IMG_DIR/$h.png" 2>/dev/null || printf '0')"
    snippet="Image · $(human_size "$size")"
    if [ -f "$THUMB_DIR/$h.png" ]; then
      preview="$THUMB_DIR/$h.png"
    else
      preview="$IMG_DIR/$h.png"
    fi
  fi
  printf '%s\t%s\t%s\t%s\t%s\n' "$h" "$type" "$epoch" "$snippet" "$preview"
done < "$INDEX"
