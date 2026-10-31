import QtQuick
import Quickshell.Io
import qs
import "../components"

Item {
  id: root
  implicitHeight: 32
  width: 44

  ModulePill {
    id: pill
    anchors.centerIn: parent
    width: 44
    height: 32
    active: true
    fill: Colors.base
    hovered: mouse.containsMouse
    pressed: mouse.pressed

    KmdotMark {
      id: label
      anchors.centerIn: parent
      width: 24
      height: 24
      primary: Colors.primary
      accent: Colors.primary_alt
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
