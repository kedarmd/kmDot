import QtQuick
import Quickshell.Io
import qs
import "../components"

Item {
  id: root
  implicitHeight: 30
  width: Math.max(30, label.implicitWidth + 20)
  required property var tooltip

  property bool attentionOn: false

  readonly property string tooltipText: "Attention mode: " + (root.attentionOn ? "On" : "Off")

  function refresh() {
    statusProc.exec(["sh", "-c", "$HOME/.config/kmdot/quickshell/scripts/attention-mode.sh status"])
  }

  Component.onCompleted: root.refresh()

  ModulePill {
    id: pill
    anchors.centerIn: parent
    width: Math.max(30, label.implicitWidth + 20)
    height: 30
    active: root.attentionOn
    fill: Tokens.primaryContainer
    hovered: mouse.containsMouse
    pressed: mouse.pressed

    Text {
      id: label
      anchors.centerIn: parent
      text: root.attentionOn ? "\uf06e" : "\uf070"
      font.family: "JetBrainsMono Nerd Font Propo"
      font.pixelSize: 15
      color: root.attentionOn ? Tokens.on_primary_container : Colors.text_alt
      opacity: root.attentionOn || mouse.containsMouse ? 1.0 : 0.0
      Behavior on opacity {
        NumberAnimation { duration: 120 }
      }
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
    onEntered: root.tooltip.show(root, root.tooltipText)
    onExited: root.tooltip.hide()
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
