#!/usr/bin/env bash
# Called by the daemon (wl-paste --watch) on every clipboard change.
# Reads the new selection, dedupes it, and appends to the index.
#
# Storage layout ($XDG_CACHE_HOME/kmdot/clipboard):
#   index          - tab-separated: hash<TAB>type<TAB>epoch<TAB>snippet (newest first)
#   text/<hash>    - text payloads
#   img/<hash>.png - image payloads
#   thumb/<hash>.png - small previews for the launcher (only if magick/convert exists)
#
# Dedup: identical content (same sha256) is stored once; re-copying it just
# bumps it to the top of the index. Screenshots already land on the clipboard
# (hyprshot -> wl-copy --type image/png), so they're captured automatically.
set -euo pipefail

CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/kmdot/clipboard"
INDEX="$CACHE/index"
TEXT_DIR="$CACHE/text"
IMG_DIR="$CACHE/img"
THUMB_DIR="$CACHE/thumb"
TTL=86400 # 1 day

mkdir -p "$TEXT_DIR" "$IMG_DIR" "$THUMB_DIR"

TMP="$(mktemp "$CACHE/.capture.XXXXXX")"
trap 'rm -f "$TMP"' EXIT

# For images, explicitly pull image/png from the live clipboard. In this setup,
# wl-paste --watch may invoke the handler for image offers without piping the
# image bytes on stdin, so trusting stdin alone loses screenshots.
if timeout 2s wl-paste --list-types 2>/dev/null | grep -qx 'image/png'; then
  TYPE="img"
  timeout 5s wl-paste --type image/png > "$TMP" || exit 0
else
  TYPE="text"
  timeout 5s cat > "$TMP" || exit 0
fi

# Skip empty selections (e.g. apps clearing the clipboard).
if [ ! -s "$TMP" ]; then
  exit 0
fi

# Keep PNG sniffing as a fallback for manual/test invocations that pipe image
# bytes directly into this script.
if [ "$TYPE" = "text" ] && [ "$(od -An -N8 -tx1 "$TMP" | tr -d ' \n')" = "89504e470d0a1a0a" ]; then
  TYPE="img"
fi

HASH="$(sha256sum "$TMP" | cut -d' ' -f1)"

# Clipboard owners can stop answering requests. Read the payload before taking
# the history lock, so a stalled owner cannot block every launcher/list/clear.
# Each capture has a private temporary file; payload publication, index updates,
# and GC remain serialized and atomic as before.
exec 9>"$CACHE/.lock"
flock -w 5 9 || exit 0

# Store the payload atomically (mv = rename on the same filesystem, so the
# launcher never reads a partially-written file). Idempotent: same hash
# overwrites the same path.
if [ "$TYPE" = "img" ]; then
  mv "$TMP" "$IMG_DIR/$HASH.png"
  chmod 644 "$IMG_DIR/$HASH.png"
  # Best-effort thumbnail; needs ImageMagick. Temp + mv for the same reason.
  if command -v magick >/dev/null 2>&1; then
    magick "$IMG_DIR/$HASH.png" -resize 48x48 "$THUMB_DIR/.$HASH.tmp.png" 2>/dev/null \
      && mv "$THUMB_DIR/.$HASH.tmp.png" "$THUMB_DIR/$HASH.png" || rm -f "$THUMB_DIR/.$HASH.tmp.png"
  elif command -v convert >/dev/null 2>&1; then
    convert "$IMG_DIR/$HASH.png" -resize 48x48 "$THUMB_DIR/.$HASH.tmp.png" 2>/dev/null \
      && mv "$THUMB_DIR/.$HASH.tmp.png" "$THUMB_DIR/$HASH.png" || rm -f "$THUMB_DIR/.$HASH.tmp.png"
  fi
  SNIPPET="Image"
else
  # Snippet for the list: first line, tabs/newlines -> space, capped.
  SNIPPET="$(tr '\t\r' '  ' < "$TMP" | sed -n '1p' | cut -c1-120)"
  mv "$TMP" "$TEXT_DIR/$HASH"
  chmod 644 "$TEXT_DIR/$HASH"
fi

# Rewrite the index: dedupe (remove any prior line with this hash), expire old
# entries, prepend the new one.
NOW="$(date +%s)"
{
  printf '%s\t%s\t%s\t%s\n' "$HASH" "$TYPE" "$NOW" "$SNIPPET"
  if [ -f "$INDEX" ]; then
    awk -F'\t' -v h="$HASH" -v now="$NOW" -v ttl="$TTL" '$1 != h && (now - $3) <= ttl' "$INDEX"
  fi
} > "$INDEX.tmp" && mv "$INDEX.tmp" "$INDEX"

# Best-effort: drop payloads no longer referenced by the index.
awk -F'\t' '{print $1}' "$INDEX" > "$CACHE/.live-hashes"
for f in "$TEXT_DIR"/* "$IMG_DIR"/*.png "$THUMB_DIR"/*.png; do
  [ -e "$f" ] || continue
  h="$(basename "$f" .png)"
  if ! grep -qxF "$h" "$CACHE/.live-hashes"; then
    rm -f "$f"
  fi
done
rm -f "$CACHE/.live-hashes"
