#!/usr/bin/env bash
tmpfile="/tmp/screenshot_edit.png"
grim -g "$(slurp)" "$tmpfile" && swappy -f "$tmpfile"

