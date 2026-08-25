import QtQuick
import qs

// Material 3 chip: active = primaryContainer fill + bold on_primary_container
// text (filled tonal chip); inactive = transparent + outline text with a hover
// state layer; disabled = dimmed. Full-pill radius.
Rectangle {
  id: root

  property bool active: false
  property bool filled: false
  property bool enabled: true
  property string text: ""
  property string glyph: ""
  property real glyphSize: 12
  property real textSize: 12
  property color fillColor: Tokens.primaryContainer
  property color inactiveFillColor: Tokens.surfaceContainerHighest
  property color activeTextColor: Tokens.on_primary_container

  signal clicked

  property real horizontalPadding: 12

  implicitHeight: 30
  implicitWidth: row.implicitWidth + horizontalPadding * 2
  radius: height / 2
  color: !root.enabled ? root.inactiveFillColor
    : root.active ? root.fillColor
    : root.filled ? root.inactiveFillColor : "transparent"

  Behavior on color {
    ColorAnimation {
      duration: 150
    }
  }

  readonly property bool hovering: mouse.containsMouse
  readonly property bool pressed: mouse.pressed
  readonly property color fg: !root.enabled
    ? Tokens.stateDisabled
    : root.active
      ? root.activeTextColor
      : (root.hovering ? Tokens.on_surface : Tokens.on_surface_variant)

  Row {
    id: row
    anchors.centerIn: parent
    spacing: 6

    Text {
      visible: root.glyph !== ""
      text: root.glyph
      font.family: "JetBrainsMono Nerd Font Propo"
      font.pixelSize: root.glyphSize
      font.weight: root.active ? Font.Bold : Font.Normal
      color: root.fg
    }

    Text {
      visible: root.text !== ""
      text: root.text
      font.family: "JetBrainsMono Nerd Font Propo"
      font.pixelSize: root.textSize
      font.weight: root.active ? Font.Bold : Font.Normal
      color: root.fg
    }
  }

  StateLayer {
    anchors.fill: parent
    radius: parent.radius
    hovered: root.hovering
    pressed: root.pressed
    enabled: root.enabled
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
