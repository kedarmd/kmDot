import QtQuick
import Quickshell.Io
import qs

Item {
  id: root
  implicitHeight: 30
  width: label.implicitWidth + 20

  Text {
    id: label
    anchors.centerIn: parent
    text: " kmDot"
    font.family: "JetBrainsMono Nerd Font Propo"
    font.pixelSize: 14
    font.weight: Font.DemiBold
    color: Colors.primary
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: kmdotProc.exec(["sh", "-c", "$HOME/.config/kmdot/quickshell/scripts/toggle.sh kmdot-kmdot"])
  }

  Process {
    id: kmdotProc
  }
}
