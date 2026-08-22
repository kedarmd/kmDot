#!/usr/bin/env bash

BIN="$HOME/.local/bin/handy"
SVC="com.pais.handy.SingleInstance"
KEY_HELPER="$HOME/.config/kmdot/hyprland/scripts/handy_record_key.sh"

has_service() {
	gdbus call --session --dest org.freedesktop.DBus \
		--object-path /org/freedesktop/DBus \
		--method org.freedesktop.DBus.NameHasOwner "$SVC" 2>/dev/null |
		grep -q 'true'
}

recording_visible() {
	hyprctl clients 2>/dev/null | grep -q "title: Recording"
}

# While recording, plain Enter submits (stop + auto_submit) and plain Escape
# cancels. The binds are compositor-level because the Recording window is
# no_focus and can never receive keys directly. They are registered live via
# hyprctl eval (this Hyprland build rejects `keyword` for binds) and are
# NON-consuming so normal typing keeps working even if one lingers.
bind_record_keys() {
	hyprctl eval "hl.bind(\"RETURN\", hl.dsp.exec_cmd(\"$KEY_HELPER submit\"), { non_consuming = true })" >/dev/null 2>&1 || true
	hyprctl eval "hl.bind(\"ESCAPE\", hl.dsp.exec_cmd(\"$KEY_HELPER cancel\"), { non_consuming = true })" >/dev/null 2>&1 || true
}

unbind_record_keys() {
	hyprctl eval "hl.unbind(\"RETURN\")" >/dev/null 2>&1 || true
	hyprctl eval "hl.unbind(\"ESCAPE\")" >/dev/null 2>&1 || true
}

# Never leave stale grabs behind from a crashed/killed session.
unbind_record_keys

if ! has_service; then
	setsid nohup "$BIN" --start-hidden >/dev/null 2>&1 &
	for _ in $(seq 1 30); do
		has_service && break
		sleep 0.5
	done
fi

if ! has_service; then
	exit 1
fi

if recording_visible; then
	# Drop the grabs BEFORE stopping so a fast second press can't restart
	# a fresh recording through a still-installed bind.
	unbind_record_keys
	"$BIN" --toggle-transcription >/dev/null 2>&1
	exit 0
fi

for _ in $(seq 1 15); do
	if recording_visible; then
		bind_record_keys
		exit 0
	fi
	"$BIN" --toggle-transcription >/dev/null 2>&1
	sleep 2
done

exit 1
