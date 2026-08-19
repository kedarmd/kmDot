import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
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
  property var points: []
  property var _raw: []
  // Epoch (seconds) marking where the current graph begins. Points older than
  // this are dropped, so the graph starts fresh after a full charge or a manual
  // clear. 0 = show the full UPower history window.
  property var graphStartEpoch: 0
  property bool _wasFull: false

  readonly property string sockPath: {
    const rt = Quickshell.env("XDG_RUNTIME_DIR")
    return (rt ? rt : "/tmp") + "/kmdot-battery.sock"
  }

  readonly property var battery: UPower.displayDevice
  readonly property bool present: battery ? battery.isPresent : false
  readonly property int percent: root.percentOf(battery)
  readonly property bool charging: root.present && battery.state === UPowerDeviceState.Charging
  readonly property bool discharging: root.present && battery.state === UPowerDeviceState.Discharging
  readonly property bool full: root.present && battery.state === UPowerDeviceState.FullyCharged
  readonly property real rate: root.present ? battery.changeRate : 0

  readonly property string statusWord: !root.present ? "No battery"
    : root.full ? "Fully charged"
    : root.charging ? "Charging"
    : root.discharging ? "Discharging"
    : UPowerDeviceState.toString(battery.state)

  readonly property color statusColor: !root.present ? Colors.muted
    : root.charging || root.full ? Colors.success
    : root.discharging ? Colors.warning
    : Colors.muted

  // When the battery first reaches fully-charged (100%), clear the old graph so
  // the newer 100% point is the fresh starting point for the new charge cycle.
  onFullChanged: {
    if (root.full && !root._wasFull) root.clearGraph()
    root._wasFull = root.full
  }

  function isProfileActive(profile) {
    return PowerProfiles.profile === profile
  }

  function percentOf(dev) {
    if (!dev) return 0
    let p = dev.percentage
    if (p <= 1.5) p = p * 100
    return Math.max(0, Math.min(100, Math.round(p)))
  }

  function batteryGlyph() {
    const cap = root.percent
    if (cap <= 20) return "\uf244"
    if (cap <= 40) return "\uf243"
    if (cap <= 60) return "\uf242"
    if (cap <= 80) return "\uf241"
    return "\uf240"
  }

  function formatTime(s) {
    if (!s || s <= 0) return ""
    const m = Math.round(s / 60)
    if (m <= 0) return "<1m"
    if (m < 60) return m + "m"
    const h = Math.floor(m / 60)
    const rem = m % 60
    return h + "h" + (rem > 0 ? " " + rem + "m" : "")
  }

  function hhmm(epoch) {
    const d = new Date(epoch * 1000)
    const h = d.getHours()
    const m = d.getMinutes()
    return (h < 10 ? "0" : "") + h + ":" + (m < 10 ? "0" : "") + m
  }

  function downsample(pts) {
    const cap = 90
    if (pts.length <= cap) return pts
    const step = Math.ceil(pts.length / cap)
    const out = []
    for (let i = 0; i < pts.length; i += step) out.push(pts[i])
    out.push(pts[pts.length - 1])
    return out
  }

  function buildHistory() {
    const pts = []
    for (const line of root._raw) {
      const parts = line.split(/\s+/)
      if (parts.length < 3) continue
      const epoch = parseInt(parts[0], 10)
      const pct = parseFloat(parts[1])
      if (!isFinite(epoch) || !isFinite(pct)) continue
      pts.push({ epoch: epoch, pct: pct })
    }
    root._raw = []
    pts.reverse()
    const start = root.graphStartEpoch
    const filtered = start > 0 ? pts.filter(p => p.epoch >= start) : pts
    root.points = root.downsample(filtered)
    graphCanvas.requestPaint()
  }

  function loadHistory() {
    root._raw = []
    histProc.exec(["sh", "-c", "$HOME/.config/kmdot/quickshell/scripts/battery-history.sh"])
  }

  // Reset the graph so it only shows data from this moment onward (fresh start).
  function clearGraph() {
    root.graphStartEpoch = Math.floor(Date.now() / 1000)
    root.points = []
    graphCanvas.requestPaint()
  }

  function pickScreen() {
    posProc.exec(["sh", "-c", "hyprctl cursorpos"])
  }

  function open() {
    if (root.scope && root.scope.activeLauncher) root.scope.activeLauncher.closeLauncher()
    if (root.scope && root.scope.volumePopup && root.scope.volumePopup !== root) root.scope.volumePopup.close()
    if (root.scope && root.scope.brightnessPopup && root.scope.brightnessPopup !== root) root.scope.brightnessPopup.close()
    if (root.scope && root.scope.calendarPopup) root.scope.calendarPopup.close()
    if (root.scope && root.scope.serverModeDropdown) root.scope.serverModeDropdown.close()
    root.opened = true
    root.loadHistory()
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
    interval: 30000
    repeat: true
    running: root.opened
    onTriggered: root.loadHistory()
  }

  Process {
    id: histProc
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function(data) {
        const line = String(data).trim()
        if (line) root._raw.push(line)
      }
    }
    onExited: root.buildHistory()
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
    }

    Rectangle {
      id: card
      width: 380
      height: body.implicitHeight + 32
      radius: 20
      color: Tokens.surfaceContainerHigh

      anchors {
        top: parent.top
        topMargin: 48
        right: parent.right
        rightMargin: 10
      }

      MouseArea {
        anchors.fill: parent
      }

      Column {
        id: body
        anchors {
          top: parent.top
          left: parent.left
          right: parent.right
          margins: 16
        }
        spacing: 10

        Row {
          width: parent.width
          spacing: 10

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.charging ? "\uf0e7 " + root.batteryGlyph() : root.batteryGlyph()
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 26
            color: root.charging ? Colors.success : Colors.text
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
            text: root.statusWord
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 14
            color: root.statusColor
            horizontalAlignment: Text.AlignRight
          }
        }

        Text {
          width: parent.width
          visible: !root.full
          text: root.charging
            ? "Charging at " + root.rate.toFixed(1) + " W"
            : "Discharging at " + root.rate.toFixed(1) + " W"
          font.family: "JetBrainsMono Nerd Font Propo"
          font.pixelSize: 13
          color: Colors.text_alt
        }

        Text {
          width: parent.width
          visible: !root.full
          text: root.charging
            ? "Full in " + (battery.timeToFull > 0 ? root.formatTime(battery.timeToFull) : "\u2014")
            : "\u2248 " + (battery.timeToEmpty > 0 ? root.formatTime(battery.timeToEmpty) : "\u2014") + " left"
          font.family: "JetBrainsMono Nerd Font Propo"
          font.pixelSize: 13
          color: Colors.muted
        }

        Rectangle {
          width: parent.width
          height: 1
          color: Tokens.divider
        }

        Row {
          width: parent.width

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Battery usage"
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 12
            color: Colors.muted
          }

          Item { width: 1; height: 1 }

          Rectangle {
            id: clearBtn
            anchors.verticalCenter: parent.verticalCenter
            height: 20
            width: clearRow.implicitWidth + 14
            radius: height / 2
            color: clearHover.containsMouse ? Tokens.stateHover : "transparent"
            border.width: 1
            border.color: Tokens.outlineVariant

            Row {
              id: clearRow
              anchors.centerIn: parent
              spacing: 4

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "\uf2ed"
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 11
                color: Colors.text_alt
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Clear"
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 11
                color: Colors.text_alt
              }
            }

            MouseArea {
              id: clearHover
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.clearGraph()
            }
          }
        }

        Canvas {
          id: graphCanvas
          width: parent.width
          height: 120

          onPaint: {
            const ctx = getContext("2d")
            if (!ctx) return
            ctx.clearRect(0, 0, width, height)
            const pts = root.points
            if (pts.length < 2) return

            const L = 2
            const R = 2
            const T = 14
            const B = 4
            const w = width - L - R
            const h = height - T - B
            const t0 = pts[0].epoch
            const t1 = pts[pts.length - 1].epoch
            const span = Math.max(1, t1 - t0)
            const X = (e) => L + (e - t0) / span * w
            const Y = (p) => T + (100 - p) / 100 * h

            ctx.lineWidth = 1
            ctx.strokeStyle = Tokens.outlineVariant
            ctx.beginPath()
            ctx.moveTo(L, Y(50))
            ctx.lineTo(L + w, Y(50))
            ctx.stroke()

            ctx.font = "10px 'JetBrainsMono Nerd Font Propo'"
            ctx.fillStyle = Colors.muted
            ctx.fillText("50%", L + 2, Y(50) - 3)

            ctx.beginPath()
            ctx.moveTo(X(pts[0].epoch), Y(pts[0].pct))
            for (let i = 1; i < pts.length; i++) ctx.lineTo(X(pts[i].epoch), Y(pts[i].pct))
            ctx.strokeStyle = Colors.primary
            ctx.lineWidth = 2
            ctx.stroke()

            const lx = X(pts[pts.length - 1].epoch)
            const ly = Y(pts[pts.length - 1].pct)
            ctx.fillStyle = Colors.primary
            ctx.beginPath()
            ctx.arc(lx, ly, 3, 0, Math.PI * 2)
            ctx.fill()

            ctx.fillStyle = Colors.text
            ctx.fillText(Math.round(pts[pts.length - 1].pct) + "%",
              Math.max(2, Math.min(L + w - 30, lx - 12)), T - 4)
          }
        }

        Row {
          width: parent.width
          Text {
            text: root.points.length > 0 ? root.hhmm(root.points[0].epoch) : ""
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 10
            color: Colors.muted
          }
          Item { width: 1; height: 1 }
          Text {
            text: root.points.length > 0 ? "now" : ""
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 10
            color: Colors.muted
          }
        }

        Rectangle {
          width: parent.width
          height: 1
          color: Tokens.divider
        }

        Text {
          width: parent.width
          text: "Power profile"
          font.family: "JetBrainsMono Nerd Font Propo"
          font.pixelSize: 12
          color: Colors.muted
        }

        Row {
          width: parent.width
          spacing: 8

          PillButton {
            width: (parent.width - 16) / 3
            height: 30
            active: root.isProfileActive(PowerProfile.PowerSaver)
            text: "Power Saver"
            textSize: 12
            onClicked: PowerProfiles.profile = PowerProfile.PowerSaver
          }

          PillButton {
            width: (parent.width - 16) / 3
            height: 30
            active: root.isProfileActive(PowerProfile.Balanced)
            text: "Balanced"
            textSize: 12
            onClicked: PowerProfiles.profile = PowerProfile.Balanced
          }

          PillButton {
            width: (parent.width - 16) / 3
            height: 30
            opacity: PowerProfiles.hasPerformanceProfile ? 1.0 : 0.4
            active: root.isProfileActive(PowerProfile.Performance)
            enabled: PowerProfiles.hasPerformanceProfile
            text: "Performance"
            textSize: 12
            onClicked: PowerProfiles.profile = PowerProfile.Performance
          }
        }
      }
    }
  }
}
