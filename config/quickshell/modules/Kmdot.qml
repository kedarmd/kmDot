import QtQuick
import Quickshell.Io
import qs
import "../components"

Item {
  id: root
  implicitHeight: 30
  width: label.implicitWidth + 20

  ModulePill {
    id: pill
    anchors.centerIn: parent
    width: label.implicitWidth + 20
    height: 30
    active: true
    fill: Tokens.primaryContainer
    hovered: mouse.containsMouse
    pressed: mouse.pressed

    Text {
      id: label
      anchors.centerIn: parent
      text: " kmDot"
      font.family: "JetBrainsMono Nerd Font Propo"
      font.pixelSize: 14
      font.weight: Font.DemiBold
      color: Tokens.on_primary_container
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: kmdotProc.exec(["sh", "-c", "$HOME/.config/kmdot/quickshell/scripts/toggle.sh kmdot-kmdot"])
  }

  Process {
    id: kmdotProc
  }
}
