import QtQuick
import Quickshell.Io
import qs
import "../components"

Item {
  id: root
  implicitHeight: 30
  width: Math.max(30, label.implicitWidth + 20)
  required property var tooltip

  property bool dndOn: false
  property int count: 0

  readonly property string icon: dndOn ? "󰂛" : "󰂚"
  readonly property string tooltipText: dndOn
    ? ("Do Not Disturb enabled" + (count > 0 ? " • " + count + " pending notifications" : ""))
    : "Do Not Disturb disabled"

  Process {
    id: stateProc
    command: ["sh", "-c", "swaync-client -D -sw"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: root.dndOn = this.text.trim() === "true"
    }
  }

  Process {
    id: countProc
    command: ["sh", "-c", "swaync-client -c -sw"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: root.count = parseInt(this.text.trim()) || 0
    }
  }

  Timer {
    interval: 3000
    running: true
    repeat: true
    onTriggered: {
      stateProc.running = true
      countProc.running = true
    }
  }

  ModulePill {
    id: pill
    anchors.centerIn: parent
    width: Math.max(30, label.implicitWidth + 20)
    height: 30
    active: root.dndOn
    fill: root.dndOn && root.count > 0 ? Tokens.errorContainer : Tokens.warningContainer
    hovered: mouse.containsMouse
    pressed: mouse.pressed

    Text {
      id: label
      anchors.centerIn: parent
      text: count > 0 ? icon + " " + count : icon
      font.family: "JetBrainsMono Nerd Font Propo"
      font.pixelSize: 15
      color: dndOn && count > 0 ? Tokens.on_error_container
           : dndOn ? Tokens.on_warning_container
           : Colors.text_alt
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    onClicked: {
      if (mouse.button === Qt.RightButton) {
        toggleProc.exec(["sh", "-c", "swaync-client -d -sw"])
        stateProc.running = true
      } else {
        panelProc.exec(["sh", "-c", "swaync-client -t -sw"])
      }
    }
    onEntered: root.tooltip.show(root, root.tooltipText)
    onExited: root.tooltip.hide()
  }

  Process {
    id: toggleProc
  }

  Process {
    id: panelProc
  }
}
