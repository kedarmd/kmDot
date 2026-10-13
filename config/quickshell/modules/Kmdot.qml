import QtQuick
import Quickshell.Io
import qs
import "../components"

Item {
  id: root
  implicitHeight: 32
  width: 40

  ModulePill {
    id: pill
    anchors.centerIn: parent
    width: 40
    height: 32
    active: true
    fill: Tokens.primaryContainer
    hovered: mouse.containsMouse
    pressed: mouse.pressed

    R1Icon {
      id: label
      anchors.centerIn: parent
      iconName: "kmdot"
      font.family: "JetBrainsMono Nerd Font Propo"
      font.pixelSize: 24
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
