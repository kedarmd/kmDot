import QtQuick
import qs

Rectangle {
  id: root

  property bool active: false
  property bool enabled: true
  property string text: ""
  property string glyph: ""
  property real glyphSize: 12
  property real textSize: 12

  signal clicked

  implicitHeight: 30
  radius: 8
  color: root.active ? Colors.border : "transparent"

  Behavior on color {
    ColorAnimation {
      duration: 200
    }
  }

  readonly property bool hovering: mouse.containsMouse

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
      color: root.active ? Colors.text : (root.hovering ? Colors.text : Colors.text_alt)
    }

    Text {
      visible: root.text !== ""
      text: root.text
      font.family: "JetBrainsMono Nerd Font Propo"
      font.pixelSize: root.textSize
      font.weight: root.active ? Font.Bold : Font.Normal
      color: root.active ? Colors.text : (root.hovering ? Colors.text : Colors.text_alt)
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
