#!/usr/bin/env bash

# Runs when Enter/Escape is pressed while a Handy transcription is active
# (temporary non-consuming binds registered by toggle_handy.sh). Acts ONLY if
# the Recording window still exists, so a stale bind can't start a fresh
# recording, and removes both binds once the recording has ended.

MODE="${1:-}"
BIN="$HOME/.local/bin/handy"

hyprctl clients 2>/dev/null | grep -q "title: Recording" || exit 0

unbind_binds() {
	hyprctl eval 'hl.unbind("RETURN")' >/dev/null 2>&1 || true
	hyprctl eval 'hl.unbind("ESCAPE")' >/dev/null 2>&1 || true
}

case "$MODE" in
	submit)
		# Stops the recording; Handy's auto_submit then transcribes and types
		# the result into whatever window currently has focus.
		unbind_binds
		"$BIN" --toggle-transcription >/dev/null 2>&1
		;;
	cancel)
		unbind_binds
		"$BIN" --cancel >/dev/null 2>&1
		;;
esac
