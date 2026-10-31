import QtQuick
import qs

// Shared Wi-Fi state marker. Connection is shown with state text/color;
// the glyph only distinguishes Wi-Fi on from Wi-Fi off.
R1Icon {
  id: root
  property bool connected: false
  property bool radioEnabled: true

  font.pixelSize: 20
  iconName: !root.radioEnabled ? "wifi-off" : "wifi"
}
