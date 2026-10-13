import QtQuick
import Quickshell.Io
import qs
import "../components"

Item {
  id: root
  implicitHeight: 32
  width: 36

  property bool attentionOn: false

  function refresh() {
    statusProc.exec(["sh", "-c", "$HOME/.config/kmdot/quickshell/scripts/attention-mode.sh status"])
  }

  Component.onCompleted: root.refresh()

  ModulePill {
    id: pill
    anchors.centerIn: parent
    width: root.width
    height: 32
    active: root.attentionOn
    fill: Tokens.primaryContainer
    hovered: mouse.containsMouse
    pressed: mouse.pressed

    Text {
      id: label
      anchors.centerIn: parent
      text: root.attentionOn ? "\uf06e" : "\uf070"
      font.family: "JetBrainsMono Nerd Font Propo"
      font.pixelSize: 20
      color: root.attentionOn ? Tokens.on_primary_container : Colors.text
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton
    cursorShape: Qt.PointingHandCursor
    onClicked: {
      toggleProc.exec(["sh", "-c", "$HOME/.config/kmdot/quickshell/scripts/attention-mode.sh " + (root.attentionOn ? "off" : "on")])
    }
  }

  Process {
    id: statusProc
    stdout: StdioCollector {
      onStreamFinished: root.attentionOn = this.text.trim() === "on"
    }
  }

  Process {
    id: toggleProc
    onExited: root.refresh()
  }
}
