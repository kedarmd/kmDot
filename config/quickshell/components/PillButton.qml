import QtQuick
import qs

// Material 3 chip: active = primaryContainer fill + bold on_primary_container
// text (filled tonal chip); inactive = transparent + outline text with a hover
// state layer; disabled = dimmed. Full-pill radius.
Rectangle {
  id: root

  property bool active: false
  property bool filled: false
  property bool keyboardSelected: false
  property bool emphasized: false
  property bool enabled: true
  property string text: ""
  property string glyph: ""
  property real glyphSize: 12
  property real textSize: 14
  property color fillColor: Tokens.primaryContainer
  property color inactiveFillColor: Colors.surface_alt
  property color activeTextColor: Tokens.on_primary_container

  signal clicked

  activeFocusOnTab: root.enabled
  Keys.onReturnPressed: if (root.enabled) root.clicked()
  Keys.onEnterPressed: if (root.enabled) root.clicked()
  Keys.onSpacePressed: if (root.enabled) root.clicked()

  property real horizontalPadding: 12

  implicitHeight: 40
  implicitWidth: row.implicitWidth + horizontalPadding * 2
  radius: height / 2
  opacity: root.enabled ? 1 : 0.38
  color: !root.enabled ? root.inactiveFillColor
    : root.pressed ? Tokens.primaryContainer
    : root.hovering ? Colors.border
    : root.active ? root.fillColor
    : root.filled ? root.inactiveFillColor : "transparent"
  border.width: root.keyboardSelected || root.activeFocus ? 2 : 0
  border.color: Colors.primary

  Behavior on color {
    ColorAnimation {
      duration: 150
    }
  }

  readonly property bool hovering: mouse.containsMouse
  readonly property bool pressed: mouse.pressed
  readonly property color fg: !root.enabled
    ? Colors.text
    : root.pressed || root.active
      ? root.activeTextColor
      : (root.hovering || root.filled ? Colors.text : Tokens.on_surface_variant)

  Row {
    id: row
    anchors.centerIn: parent
    spacing: 6

    R1Icon {
      visible: root.glyph !== ""
      glyph: root.glyph
      font.family: "JetBrainsMono Nerd Font Propo"
      font.pixelSize: root.glyphSize
      font.weight: root.active ? Font.Bold : Font.Normal
      color: root.fg
    }

    Text {
      visible: root.text !== ""
      text: root.text
      font.family: "JetBrainsMono Nerd Font"
      font.pixelSize: root.textSize
      font.weight: root.active || root.emphasized ? Font.DemiBold : Font.Normal
      color: root.fg
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    enabled: root.enabled
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
