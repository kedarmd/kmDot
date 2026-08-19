import QtQuick
import Quickshell.Io
import qs
import "../components"

Item {
  id: root
  implicitHeight: 30
  width: Math.max(30, label.implicitWidth + 20)

  property int cur: 0
  property int max: 1
  property bool _applying: false
  property int _pending: -1

  readonly property int percent: max > 0 ? Math.round(cur * 100 / max) : 0
  readonly property int _min: Math.round(max * 5 / 100)
  readonly property string icon: {
    if (percent <= 25) return "󰃞"
    if (percent <= 50) return "󰃝"
    if (percent <= 75) return "󰃟"
    return "󰃠"
  }
  readonly property string text: icon + " " + percent + "%"

  function poll() {
    curProc.exec(["sh", "-c", "brightnessctl get"])
  }

  // Optimistic + coalesced: update the display immediately from the cached value,
  // and while a brightnessctl set is in flight just remember the latest target so
  // fast wheel scrolling never drops steps (a fresh shell process per tick would).
  function apply(target) {
    const t = Math.max(root._min, Math.min(root.max, target))
    root.cur = t
    if (root._applying) {
      root._pending = t
      return
    }
    root._applying = true
    root._pending = -1
    setProc.exec(["sh", "-c", "brightnessctl set " + t])
  }

  Component.onCompleted: {
    maxProc.exec(["sh", "-c", "brightnessctl max"])
    root.poll()
  }

  Timer {
    interval: 500
    running: true
    repeat: true
    onTriggered: root.poll()
  }

  Process {
    id: curProc
    stdout: StdioCollector {
      onStreamFinished: {
        const v = parseInt(this.text.replace(/[^0-9]/g, "")) || 0
        // While a set is in flight the actual value is mid-transition; keep the
        // optimistic display until it settles.
        if (!root._applying) root.cur = v
      }
    }
  }

  Process {
    id: maxProc
    stdout: StdioCollector {
      onStreamFinished: root.max = parseInt(this.text.replace(/[^0-9]/g, "")) || 1
    }
  }

  Process {
    id: setProc
    onExited: {
      root._applying = false
      if (root._pending >= 0) {
        const t = root._pending
        root._pending = -1
        root._applying = true
        setProc.exec(["sh", "-c", "brightnessctl set " + t])
      } else {
        root.poll()
      }
    }
  }

  ModulePill {
    id: pill
    anchors.centerIn: parent
    width: Math.max(30, label.implicitWidth + 20)
    height: 30
    hovered: mouse.containsMouse
    pressed: mouse.pressed

    Text {
      id: label
      anchors.centerIn: parent
      text: root.text
      font.family: "JetBrainsMono Nerd Font Propo"
      font.pixelSize: 14
      color: Colors.text_alt
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: toggleProc.exec(["sh", "-c", "$HOME/.config/kmdot/quickshell/scripts/toggle.sh kmdot-brightness"])
    onWheel: {
      const step = Math.max(1, Math.round(root.max * 0.02))
      root.apply(wheel.angleDelta.y > 0 ? root.cur + step : root.cur - step)
    }
  }

  Process {
    id: toggleProc
  }
}
