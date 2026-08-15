import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Wayland
import qs

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
    root.points = root.downsample(pts)
    graphCanvas.requestPaint()
  }

  function loadHistory() {
    root._raw = []
    histProc.exec(["sh", "-c", "$HOME/.config/kmdot/quickshell/scripts/battery-history.sh"])
  }

  function open() {
    if (root.scope && root.scope.activeLauncher) root.scope.activeLauncher.closeLauncher()
    root.opened = true
    root.loadHistory()
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
          color: Colors.border
        }

        Text {
          width: parent.width
          text: "Battery usage"
          font.family: "JetBrainsMono Nerd Font Propo"
          font.pixelSize: 12
          color: Colors.muted
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
            ctx.strokeStyle = Colors.border
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
          color: Colors.border
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

          Rectangle {
            width: (parent.width - 16) / 3
            height: 36
            radius: 8
            color: root.isProfileActive(PowerProfile.PowerSaver) ? Colors.surface_alt : "transparent"
            border.width: 1
            border.color: root.isProfileActive(PowerProfile.PowerSaver) ? Colors.primary : Colors.border

            Text {
              anchors.centerIn: parent
              text: "Power Saver"
              font.family: "JetBrainsMono Nerd Font Propo"
              font.pixelSize: 12
              color: root.isProfileActive(PowerProfile.PowerSaver) ? Colors.primary : Colors.text_alt
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: PowerProfiles.profile = PowerProfile.PowerSaver
            }
          }

          Rectangle {
            width: (parent.width - 16) / 3
            height: 36
            radius: 8
            color: root.isProfileActive(PowerProfile.Balanced) ? Colors.surface_alt : "transparent"
            border.width: 1
            border.color: root.isProfileActive(PowerProfile.Balanced) ? Colors.primary : Colors.border

            Text {
              anchors.centerIn: parent
              text: "Balanced"
              font.family: "JetBrainsMono Nerd Font Propo"
              font.pixelSize: 12
              color: root.isProfileActive(PowerProfile.Balanced) ? Colors.primary : Colors.text_alt
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: PowerProfiles.profile = PowerProfile.Balanced
            }
          }

          Rectangle {
            width: (parent.width - 16) / 3
            height: 36
            radius: 8
            opacity: PowerProfiles.hasPerformanceProfile ? 1.0 : 0.4
            color: root.isProfileActive(PowerProfile.Performance) ? Colors.surface_alt : "transparent"
            border.width: 1
            border.color: root.isProfileActive(PowerProfile.Performance) ? Colors.primary : Colors.border

            Text {
              anchors.centerIn: parent
              text: "Performance"
              font.family: "JetBrainsMono Nerd Font Propo"
              font.pixelSize: 12
              color: root.isProfileActive(PowerProfile.Performance) ? Colors.primary : Colors.text_alt
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              enabled: PowerProfiles.hasPerformanceProfile
              onClicked: PowerProfiles.profile = PowerProfile.Performance
            }
          }
        }
      }
    }
  }
}
