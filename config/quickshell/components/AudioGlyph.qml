import QtQuick
import qs

// Compact Nerd Font glyph used by the per-device audio controls.
Text {
  id: root
  property bool isInput: false
  property bool muted: false
  text: root.isInput ? "\uf130" : (root.muted ? "\uf026" : "\uf028")
  font.family: "JetBrainsMono Nerd Font Propo"
  font.pixelSize: 18
  horizontalAlignment: Text.AlignHCenter
  verticalAlignment: Text.AlignVCenter
  color: root.color
}
