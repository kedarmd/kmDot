import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs
import "../components"

PopupBase {
  id: root
  sockName: "kmdot-battery"
  cardWidth: 424
  // Keep the card close to its content; the current 624px fixed height leaves
  // a large unused area below the power profile note.
  cardMinHeight: 0

  // anchorItem seam: set by the bar module before toggling (see PopupBase).
  property var points: []
  property var _raw: []
  property bool graphHovered: false
  property real graphHoverX: 0

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
    let h = d.getHours()
    const m = d.getMinutes()
    const ampm = h >= 12 ? "PM" : "AM"
    h = h % 12
    if (h === 0) h = 12
    return h + ":" + (m < 10 ? "0" : "") + m + " " + ampm
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

  function graphEpochAtX(x) {
    if (root.points.length < 2) return 0
    const left = 2
    const width = graphCanvas.width - 4
    const first = root.points[0].epoch
    const span = Math.max(1, root.points[root.points.length - 1].epoch - first)
    const fraction = Math.max(0, Math.min(1, (x - left) / width))
    return Math.round(first + fraction * span)
  }

  function graphPctAtEpoch(epoch) {
    const pts = root.points
    if (pts.length === 0) return 0
    if (epoch <= pts[0].epoch) return pts[0].pct
    for (let i = 1; i < pts.length; i++) {
      if (pts[i].epoch >= epoch) {
        const before = pts[i - 1]
        const after = pts[i]
        const span = after.epoch - before.epoch
        if (span <= 0) return after.pct
        const fraction = (epoch - before.epoch) / span
        return before.pct + (after.pct - before.pct) * fraction
      }
    }
    return pts[pts.length - 1].pct
  }

  function graphYForPct(pct) {
    const top = 14
    const height = graphCanvas.height - top - 4
    return top + (100 - pct) / 100 * height
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

  function refreshItems() {
    root.loadHistory()
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

  // Card body follows the approved Penpot battery panel.
  Column {
    width: parent.width
    spacing: 16

    Row {
      width: parent.width
      spacing: 12
      R1Icon { glyph: "󰁹"; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 20; color: Colors.text; anchors.verticalCenter: parent.verticalCenter }
      Text { text: "Battery"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 24; font.weight: Font.DemiBold; color: Colors.text; anchors.verticalCenter: parent.verticalCenter }
    }

    Column {
      width: parent.width
      spacing: 4
      Row {
        spacing: 8
        Text { id: percentValue; text: root.present ? root.percent.toString() : "—"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 48; font.weight: Font.DemiBold; color: root.charging ? Colors.success : Colors.text }
        Text { text: "%"; visible: root.present; anchors.baseline: percentValue.baseline; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 24; color: root.charging ? Colors.success : Colors.text_alt }
      }
      Text {
        width: parent.width
        text: !root.present ? "No battery detected" : root.charging ? "Charging" : (root.full ? "Fully charged" : "Until your next recharge")
        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: root.charging ? 24 : 16; color: Colors.text
      }
      Text {
        width: parent.width
        text: "About " + (root.formatTime(root.charging ? battery.timeToFull : battery.timeToEmpty) || "—") + (root.charging ? " until full · Charging at " : " remaining · Using ") + root.rate.toFixed(1) + " W"
        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: Colors.text_alt
        visible: root.present && !root.full
      }
    }

    Rectangle {
      width: parent.width
      visible: root.present && !root.charging
      radius: 24
      color: Colors.surface_alt
      implicitHeight: chartColumn.implicitHeight + 32
      Column {
        id: chartColumn
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
        spacing: 8
        Text { text: "LAST 12 HOURS"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: Colors.text_alt }
        Item {
          width: parent.width
          height: 102
          Text {
            anchors.centerIn: parent
            visible: root.points.length < 2
            text: "No charge history yet"
            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: Colors.text_alt
          }
          Row {
            anchors.fill: parent
            spacing: 6
            Column {
              width: 24
              height: parent.height - 8
              spacing: 0
              Text { text: "100"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: Colors.text_alt }
              Item { width: 1; height: 14 }
              Text { text: "50"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: Colors.text_alt }
              Item { width: 1; height: 14 }
              Text { text: "0"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: Colors.text_alt }
            }
            Canvas {
              id: graphCanvas
              width: parent.width - 30
              height: parent.height
              onPaint: {
                const ctx = getContext("2d")
                if (!ctx) return
                ctx.clearRect(0, 0, width, height)
                const pts = root.points
                const L = 2, R = 2, T = 8, B = 8
                const w = width - L - R, h = height - T - B
                const Y = p => T + (100 - p) / 100 * h
                ctx.lineWidth = 1
                ctx.strokeStyle = Colors.outline_variant
                for (const val of [0, 50, 100]) {
                  ctx.beginPath(); ctx.moveTo(L, Y(val)); ctx.lineTo(L + w, Y(val)); ctx.stroke()
                }
                if (pts.length < 2) return
                const t0 = pts[0].epoch
                const span = Math.max(1, pts[pts.length - 1].epoch - t0)
                const X = e => L + (e - t0) / span * w
                ctx.beginPath(); ctx.moveTo(X(pts[0].epoch), Y(pts[0].pct))
                for (let n = 1; n < pts.length; n++) ctx.lineTo(X(pts[n].epoch), Y(pts[n].pct))
                ctx.strokeStyle = Colors.primary; ctx.lineWidth = 2; ctx.stroke()
                const last = pts[pts.length - 1], lx = X(last.epoch), ly = Y(last.pct)
                ctx.fillStyle = Colors.primary; ctx.beginPath(); ctx.arc(lx, ly, 2, 0, Math.PI * 2); ctx.fill()
                ctx.font = '11px "JetBrainsMono Nerd Font"'; ctx.fillStyle = Colors.primary
                ctx.fillText(Math.round(last.pct) + "%", Math.max(2, Math.min(width - 30, lx - 18)), Math.min(height - 1, ly + 18))
              }
            }
          }
        }
        Row {
          width: parent.width
          Text { id: startTimeText; text: root.points.length > 0 ? root.hhmm(root.points[0].epoch) : ""; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: Colors.text_alt }
          Item { width: parent.width - startTimeText.implicitWidth - nowText.implicitWidth; height: 1 }
          Text { id: nowText; text: "Now"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: Colors.text_alt }
        }
      }
    }

    Text { width: parent.width; text: "POWER PROFILE"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: Colors.text_alt }
    Row {
      width: parent.width
      spacing: 8
      PillButton { width: (parent.width - 16) / 3; height: 40; filled: true; active: root.isProfileActive(PowerProfile.PowerSaver); text: "Saver"; textSize: 14; onClicked: PowerProfiles.profile = PowerProfile.PowerSaver }
      PillButton { width: (parent.width - 16) / 3; height: 40; filled: true; active: root.isProfileActive(PowerProfile.Balanced); text: "Balanced"; textSize: 14; onClicked: PowerProfiles.profile = PowerProfile.Balanced }
      PillButton { width: (parent.width - 16) / 3; height: 40; filled: true; active: root.isProfileActive(PowerProfile.Performance); enabled: PowerProfiles.hasPerformanceProfile; text: "Performance"; textSize: 14; onClicked: PowerProfiles.profile = PowerProfile.Performance }
    }
    Text {
      width: parent.width
      text: !PowerProfiles.hasPerformanceProfile ? "Performance is unavailable on this device." : PowerProfiles.profile === PowerProfile.PowerSaver ? "Lower power use for longer battery life." : PowerProfiles.profile === PowerProfile.Performance ? "More power for demanding tasks." : "Balanced power for everyday work."
      font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: Colors.text_alt
    }
  }
}
