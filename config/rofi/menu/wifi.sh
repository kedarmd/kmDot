#!/usr/bin/env bash

# Fix locale issues for rofi/xkbcommon
export LANG=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8

# Ensure NetworkManager is available
if ! command -v nmcli >/dev/null 2>&1; then
  notify-send "Wi-Fi" "nmcli (NetworkManager) not found"
  exit 1
fi

# Make sure Wi-Fi is enabled
nmcli radio wifi on >/dev/null 2>&1

# Get Wi-Fi list in a parseable format:
# ACTIVE:SSID:SECURITY
wifi_list=$(nmcli -t -f ACTIVE,SSID,SECURITY device wifi list | sed '/^:/d')

if [ -z "$wifi_list" ]; then
  notify-send "Wi-Fi" "No networks found"
  exit 0
fi

# Build menu lines like:
#   * MyWifi [WPA2]
#     OtherNet [OPEN]
menu_lines=$(
  printf '%s\n' "$wifi_list" | while IFS=':' read -r active ssid security; do
    [ -z "$ssid" ] && continue

    # Mark currently active network
    if [ "$active" = "yes" ]; then
      prefix="* "
    else
      prefix="  "
    fi

    [ -z "$security" ] && security="OPEN"
    printf '%s%s [%s]\n' "$prefix" "$ssid" "$security"
  done
)

# Show menu via rofi
choice=$(printf '%s\n' "$menu_lines" | rofi -dmenu -i -p "Wi-Fi")

# User cancelled
[ -z "$choice" ] && exit 0

# Extract SSID from choice:
# choice looks like: "* MyWifi [WPA2]" or "  OtherNet [OPEN]"
# Strip leading marker and take text before last " ["
ssid=$(echo "$choice" | sed 's/^[* ]*//' | sed 's/ \[[^]]*\]$//')

# Get security for chosen SSID from original wifi_list
security=$(printf '%s\n' "$wifi_list" | awk -F: -v s="$ssid" '$2==s {print $3; exit}')

# Is this the currently active SSID?
current_ssid=$(nmcli -t -f ACTIVE,SSID dev wifi | awk -F: '$1=="yes"{print $2}')

if [ "$ssid" = "$current_ssid" ]; then
  # Offer to disconnect
  action=$(printf "Disconnect\nCancel\n" | rofi -dmenu -i -p "$ssid")
  [ "$action" = "Disconnect" ] && nmcli con down id "$ssid"
  exit 0
fi

# Check if we already have a saved connection with this name
if nmcli -t -f NAME connection show | grep -Fxq "$ssid"; then
  # Use the existing saved connection (no password prompt)
  nmcli connection up id "$ssid" && exit 0
fi

# New network or unsaved connection -> may need password
if [ -n "$security" ] && [ "$security" != "--" ] && [ "$security" != "NONE" ] && [ "$security" != "OPEN" ]; then
  pass=$(rofi -dmenu -password -p "Password for $ssid")
  [ -z "$pass" ] && exit 0
  nmcli dev wifi connect "$ssid" password "$pass"
else
  nmcli dev wifi connect "$ssid"
fi

