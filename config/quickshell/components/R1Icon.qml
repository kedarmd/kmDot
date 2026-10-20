import QtQuick
import QtQuick.Effects
import qs
import "r1icons.js" as Icons

// Text-compatible icon wrapper: known shell glyphs use the approved vectors;
// device-specific glyphs retain the existing Nerd Font fallback.
Item {
  id: root
  property string glyph: ""
  property string iconName: ""
  property font font: Qt.font({ family: "JetBrainsMono Nerd Font Propo", pixelSize: 16 })
  property color color: Colors.text
  property color accentColor: Colors.primary
  // Monochrome icons can animate their tint without decoding a new SVG
  // for every frame. Keep multicolor marks on the original SVG path.
  property bool tintVector: false
  property int horizontalAlignment: Text.AlignHCenter
  property int verticalAlignment: Text.AlignVCenter
  readonly property string text: glyph
  readonly property string resolvedName: iconName || ({
    "": "search", "": "close", "": "chevron", "": "chevron", "": "back",
    "": "terminal", "": "terminal", "󰆍": "terminal", "": "display", "": "display",
    "": "apps", "": "apps", "󰀻": "apps", "󰕰": "apps", "": "apps", "": "apps",
    "": "clipboard", "": "clipboard", "": "copy", "": "music", "": "power",
    "": "wifi", "󰤨": "wifi", "": "bluetooth", "󰂯": "bluetooth", "󰁹": "battery",
    "": "power", "": "lock", "": "moon", "󰖔": "moon", "": "logout", "": "logout",
    "": "refresh", "": "refresh", "": "keyboard", "": "mic", "󰍬": "mic",
    "": "bell", "": "bell", "󰂚": "bell", "": "server", "": "globe", "": "folder",
    "": "play", "": "pause", "": "plus", "": "trash", "": "trash",
    "": "check", "": "calendar", "": "calendar", "": "chart",
    "": "palette", "󰏘": "palette", "": "headphones"
  })[root.glyph] || ""
  readonly property bool vectorIcon: root.resolvedName !== ""
  implicitWidth: root.vectorIcon ? font.pixelSize : fallback.implicitWidth
  implicitHeight: root.vectorIcon ? font.pixelSize : fallback.implicitHeight

  Text {
    id: fallback
    anchors.fill: parent
    visible: !root.vectorIcon
    text: root.glyph
    font: root.font
    color: root.color
    horizontalAlignment: root.horizontalAlignment
    verticalAlignment: root.verticalAlignment
  }

  Image {
    anchors.centerIn: parent
    width: root.font.pixelSize
    height: root.font.pixelSize
    visible: root.vectorIcon
    opacity: root.color.a
    source: root.tintVector
      ? Icons.source(root.resolvedName, "#FFFFFF", "#FFFFFF")
      : Icons.source(root.resolvedName, root.color, root.accentColor)
    sourceSize: Qt.size(width * Screen.devicePixelRatio, height * Screen.devicePixelRatio)
    layer.enabled: root.tintVector
    layer.effect: MultiEffect {
      colorization: 1
      colorizationColor: root.color
      autoPaddingEnabled: false
    }
  }
}
