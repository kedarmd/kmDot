import QtQuick
import Quickshell.Io
import qs

Item {
  id: root
  implicitHeight: 30
  width: label.implicitWidth + 20

  property int cur: 0
  property int max: 1

  readonly property int percent: max > 0 ? Math.round(cur * 100 / max) : 0
  readonly property string icon: {
    if (percent <= 25) return "󰃞"
    if (percent <= 50) return "󰃝"
    if (percent <= 75) return "󰃟"
    return "󰃠"
  }
  readonly property string text: icon + " " + percent + "%"

  function poll() {
    curProc.running = true
    maxProc.running = true
  }

  Process {
    id: curProc
    command: ["sh", "-c", "brightnessctl get"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: root.cur = parseInt(this.text.replace(/[^0-9]/g, "")) || 0
    }
  }

  Process {
    id: maxProc
    command: ["sh", "-c", "brightnessctl max"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: root.max = parseInt(this.text.replace(/[^0-9]/g, "")) || 1
    }
  }

  Timer {
    interval: 500
    running: true
    repeat: true
    onTriggered: root.poll()
  }

  Text {
    id: label
    anchors.centerIn: parent
    text: root.text
    font.family: "JetBrainsMono Nerd Font Propo"
    font.pixelSize: 14
    color: Colors.text_alt
  }

  MouseArea {
    anchors.fill: parent
    onWheel: {
      if (wheel.angleDelta.y > 0) upProc.exec(["sh", "-c", "$HOME/.config/kmdot/quickshell/scripts/brightness.sh up"])
      else downProc.exec(["sh", "-c", "$HOME/.config/kmdot/quickshell/scripts/brightness.sh down"])
      root.poll()
    }
  }

  Process {
    id: upProc
  }

  Process {
    id: downProc
  }
}
