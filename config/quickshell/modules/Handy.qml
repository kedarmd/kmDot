import QtQuick
import Quickshell.Io
import qs
import "../components"

Item {
  id: root
  implicitHeight: 30
  width: Math.max(30, label.implicitWidth + 20)

  required property var tooltip
  required property var popup

  ModulePill {
    anchors.centerIn: parent
    width: root.width
    height: 30
    active: root.popup.opened
    hovered: mouse.containsMouse
    pressed: mouse.pressed

    Text {
      id: label
      anchors.centerIn: parent
      text: "\uf130"
      font.family: "JetBrainsMono Nerd Font Propo"
      font.pixelSize: 15
      color: root.popup.opened ? Tokens.on_primary_container : Colors.text_alt
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton
    cursorShape: Qt.PointingHandCursor
    onClicked: root.popup.toggle()
    onEntered: root.tooltip.show(root, "Handy transcription \u00b7 Super+H")
    onExited: root.tooltip.hide()
  }
}
