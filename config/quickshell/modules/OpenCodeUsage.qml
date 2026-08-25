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
    width: Math.max(30, label.implicitWidth + 20)
    height: 30
    hovered: mouse.containsMouse
    pressed: mouse.pressed

    Text {
      id: label
      anchors.centerIn: parent
      text: "\uf121"
      font.family: "JetBrainsMono Nerd Font Propo"
      font.pixelSize: 15
      color: Colors.text_alt
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton
    cursorShape: Qt.PointingHandCursor
    onClicked: {
      root.popup.anchorItem = root
      root.popup.toggle()
    }
    onEntered: root.tooltip.show(root, "OpenCode usage")
    onExited: root.tooltip.hide()
  }
}
