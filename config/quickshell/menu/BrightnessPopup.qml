import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import "../components"

PanelWindow {
  id: root
  visible: root.opened
  color: Qt.rgba(0, 0, 0, 0)
  focusable: true
  screen: Quickshell.screens.values.length > 0 ? Quickshell.screens.values[0] : null

  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
  WlrLayershell.exclusionMode: ExclusionMode.Ignore

  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }

  property bool opened: false
  property var scope: null

  property int cur: 0
  property int max: 1
  property bool _applying: false
  property int _pending: -1

  readonly property string sockPath: {
    const rt = Quickshell.env("XDG_RUNTIME_DIR")
    return (rt ? rt : "/tmp") + "/kmdot-brightness.sock"
  }

  readonly property int percent: max > 0 ? Math.round(cur * 100 / max) : 0
  readonly property int _min: Math.round(max * 5 / 100)
  readonly property string icon: {
    if (percent <= 25) return "󰃞"
    if (percent <= 50) return "󰃝"
    if (percent <= 75) return "󰃟"
    return "󰃠"
  }

  function poll() {
    curProc.exec(["sh", "-c", "brightnessctl get"])
  }

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

  function pickScreen() {
    posProc.exec(["sh", "-c", "hyprctl cursorpos"])
  }

  function open() {
    if (root.scope && root.scope.activeLauncher) root.scope.activeLauncher.closeLauncher()
    if (root.scope && root.scope.batteryPopup) root.scope.batteryPopup.close()
    if (root.scope && root.scope.volumePopup && root.scope.volumePopup !== root) root.scope.volumePopup.close()
    if (root.scope && root.scope.brightnessPopup && root.scope.brightnessPopup !== root) root.scope.brightnessPopup.close()
    root.opened = true
    root.poll()
    root.pickScreen()
    focusTimer.start()
  }

  function close() {
    root.opened = false
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  SocketServer {
    active: true
    path: root.sockPath
    handler: Socket {
      onConnectedChanged: {
        if (connected) root.toggle()
      }
    }
  }

  Timer {
    id: focusTimer
    interval: 60
    repeat: true
    onTriggered: {
      if (!root.opened) {
        focusTimer.stop()
        return
      }
      content.forceActiveFocus()
      if (content.activeFocus) focusTimer.stop()
    }
  }

  Timer {
    interval: 500
    repeat: true
    running: root.opened
    onTriggered: root.poll()
  }

  Process {
    id: curProc
    stdout: StdioCollector {
      onStreamFinished: {
        const v = parseInt(this.text.replace(/[^0-9]/g, "")) || 0
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

  Component.onCompleted: {
    maxProc.exec(["sh", "-c", "brightnessctl max"])
    root.poll()
  }

  Process {
    id: posProc
    stdout: StdioCollector {
      onStreamFinished: {
        const m = /(-?\d+),\s*(-?\d+)/.exec(String(this.text).trim())
        if (!m) return
        const X = parseInt(m[1], 10)
        const Y = parseInt(m[2], 10)
        const screens = Quickshell.screens.values
        for (let i = 0; i < screens.length; i++) {
          const s = screens[i]
          if (X >= s.x && X < s.x + s.width && Y >= s.y && Y < s.y + s.height) {
            root.screen = s
            return
          }
        }
      }
    }
  }

  Item {
    id: content
    anchors.fill: parent
    focus: true
    Keys.onEscapePressed: root.close()

    MouseArea {
      id: dismiss
      anchors.fill: parent
      onClicked: root.close()
      onWheel: {
        const step = Math.max(1, Math.round(root.max * 0.02))
        root.apply(wheel.angleDelta.y > 0 ? root.cur + step : root.cur - step)
      }
    }

    Rectangle {
      id: card
      width: 340
      height: body.implicitHeight + 32
      radius: 12
      color: Colors.surface
      border.color: Colors.border
      border.width: 1

      anchors {
        top: parent.top
        topMargin: 48
        right: parent.right
        rightMargin: 10
      }

      MouseArea {
        anchors.fill: parent
        onWheel: {
          const step = Math.max(1, Math.round(root.max * 0.02))
          root.apply(wheel.angleDelta.y > 0 ? root.cur + step : root.cur - step)
        }
      }

      Column {
        id: body
        anchors {
          top: parent.top
          left: parent.left
          right: parent.right
          margins: 16
        }
        spacing: 14

        Row {
          width: parent.width
          spacing: 10

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 26
            color: Colors.warning
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.percent + "%"
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 26
            font.weight: Font.DemiBold
            color: Colors.text
          }

          Item { width: 1; height: 1 }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Brightness"
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 14
            color: Colors.muted
            horizontalAlignment: Text.AlignRight
          }
        }

        SliderBar {
          width: parent.width
          value: root.max > 0 ? root.cur / root.max : 0
          onChanged: root.apply(Math.round(v * root.max))
        }
      }
    }
  }
}
