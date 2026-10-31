import QtQuick
import qs

// Shared Wi-Fi state marker. Keep the same on/connected glyphs in the bar,
// popup headings, and network rows.
R1Icon {
  id: root
  property bool connected: false
  property bool radioEnabled: true

  font.pixelSize: 20
  iconName: !root.radioEnabled ? "wifi-off" : root.connected ? "wifi-connected" : "wifi"
}
