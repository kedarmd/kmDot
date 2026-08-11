#!/usr/bin/env bash

BIN="$HOME/.local/bin/handy"
SVC="com.pais.handy.SingleInstance"

has_service() {
	gdbus call --session --dest org.freedesktop.DBus \
		--object-path /org/freedesktop/DBus \
		--method org.freedesktop.DBus.NameHasOwner "$SVC" 2>/dev/null |
		grep -q 'true'
}

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

if hyprctl clients 2>/dev/null | grep -q "title: Recording"; then
	"$BIN" --toggle-transcription >/dev/null 2>&1
	exit 0
fi

for _ in $(seq 1 15); do
	if hyprctl clients 2>/dev/null | grep -q "title: Recording"; then
		exit 0
	fi
	"$BIN" --toggle-transcription >/dev/null 2>&1
	sleep 2
done

exit 1
