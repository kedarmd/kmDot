import QtQuick
import Quickshell
import Quickshell.Io
import "../components"
import qs

LauncherBase {
  id: root

  sockName: "kmdot-wifi"
  title: "Wi-Fi"
  footerHint: "\u2191\u2193 navigate \u00b7 \u23ce connect \u00b7 tab toggle \u00b7 esc close"
  countShown: false
  loadingText: "Scanning for networks..."
  // Items decide whether to close themselves — the password flow keeps the launcher open.
  closeOnActivate: false

  property string pendingSsid: ""
  property var _rows: []
  property var _saved: []
  property bool _savedMode: false
  property string _state: "enabled"
  property string _lastErr: ""
  property int _emptyScans: 0

  function shellQuote(s) {
    return "'" + s.replace(/'/g, "'\\''") + "'"
  }

  function decodeNmcli(s) {
    return String(s).replace(/\\([\\:sn])/g, function(_, code) {
      if (code === ":") return ":"
      if (code === "s") return " "
      if (code === "n") return "\n"
      return "\\"
    })
  }

  function sigGlyph(sig) {
    if (sig >= 75) return "\u2588\u2588\u2588\u2588"
    if (sig >= 50) return "\u2588\u2588\u2586\u2581"
    if (sig >= 25) return "\u2588\u2584\u2581\u2581"
    return "\u2581\u2581\u2581\u2581"
  }

  function startScan() {
    root.pool = []
    root.loading = true
    root.pendingSsid = ""
    root._rows = []
    root._saved = []
    root._savedMode = false
    root._state = ""
    wifiScanProc.exec(["sh", "-c",
      "nmcli -t -f ACTIVE,SSID,SIGNAL,SECURITY device wifi list 2>/dev/null; " +
      "printf 'STATE:%s\\n' \"$(nmcli -t -f WIFI general 2>/dev/null)\"; " +
      "printf 'SAVED\\n'; nmcli -t -f NAME connection show 2>/dev/null"])
  }

  function refreshItems() {
    root._emptyScans = 0
    root.startScan()
  }

  function syncFooter() {
    root.footerActionGlyph = root._state === "enabled" ? "\uf1eb" : "\uf011"
    root.footerActionText = root._state === "enabled" ? "Wi-Fi On" : "Wi-Fi Off"
    root.footerActionActive = root._state === "enabled"
  }

  function buildPool() {
    const savedSet = {}
    for (const n of root._saved) {
      const t = root.decodeNmcli(n.trim())
      if (t) savedSet[t] = true
    }
    const items = []
    for (const line of root._rows) {
      const parts = line.split(":")
      if (parts.length < 3) continue
      const active = parts[0] === "yes"
      const ssid = root.decodeNmcli(parts.slice(1, parts.length - 2).join(":"))
      const signal = parseInt(parts[parts.length - 2], 10) || 0
      const security = parts[parts.length - 1] || ""
      if (!ssid) continue
      const open = !security || security === "--" || security === "NONE" || security === "OPEN"
      items.push({
        label: ssid,
        subtitle: (active ? "active \u00b7 " : "") + (open ? "Open" : security) + " \u00b7 " + root.sigGlyph(signal) + " " + signal + "%",
        glyph: "\uf1eb",
        ssid: ssid,
        active: active,
        saved: !!savedSet[ssid],
        open: open,
        signal: signal
      })
    }
    items.sort(function(a, b) {
      return (b.active ? 1 : 0) - (a.active ? 1 : 0) || b.signal - a.signal
    })
    root.loading = false
    root.emptyText = root._state === "disabled" ? "Wi-Fi is turned off" : "No networks found"
    root.syncFooter()
    root.pool = items
    // Right after the radio is re-enabled the device may not have cached any APs
    // yet, so a scan can legitimately return nothing — retry a couple of times.
    if (root._state === "enabled" && items.length === 0 && root._emptyScans < 2) {
      root._emptyScans++
      wifiRescanTimer.restart()
    }
  }

  Process {
    id: wifiScanProc
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function(data) {
        const line = String(data)
        if (line.startsWith("STATE:")) { root._state = line.slice(6).trim(); return }
        if (line === "SAVED") { root._savedMode = true; return }
        if (root._savedMode) { root._saved.push(line); return }
        root._rows.push(line)
      }
    }
    onExited: root.buildPool()
  }

  function connectTo(item) {
    if (item.active) {
      root.closeLauncher()
      root.runCommand("nmcli con down id " + root.shellQuote(item.ssid))
      return
    }
    if (item.saved) {
      root.closeLauncher()
      root.runCommand("nmcli connection up id " + root.shellQuote(item.ssid))
      return
    }
    if (!item.open) {
      root.pendingSsid = item.ssid
      root.startPrompt("Password for " + item.ssid)
      return
    }
    root.closeLauncher()
    root.runCommand("nmcli dev wifi connect " + root.shellQuote(item.ssid))
  }

  onActivated: function(item) {
    root.connectTo(item)
  }

  onFooterActionClicked: {
    const turnOn = root._state !== "enabled"
    root.loading = true
    root._state = turnOn ? "enabled" : "disabled"
    root.syncFooter()
    root.runCommand("nmcli radio wifi " + (turnOn ? "on" : "off"))
    wifiRefreshTimer.restart()
  }

  Timer {
    id: wifiRefreshTimer
    interval: 1200
    repeat: false
    onTriggered: root.refreshItems()
  }

  Timer {
    id: wifiRescanTimer
    interval: 2500
    repeat: false
    onTriggered: root.startScan()
  }

  onPromptSubmitted: function(text) {
    const ssid = root.pendingSsid
    if (!ssid) return
    const pass = text
    if (!pass) return
    connectProc.exec(["sh", "-c",
      "nmcli dev wifi connect " + root.shellQuote(ssid) + " password " + root.shellQuote(pass) + " 2>&1"])
  }

  Process {
    id: connectProc
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function(data) {
        const t = String(data).trim()
        if (t) root._lastErr = t
      }
    }
    onExited: function(exitCode, exitStatus) {
      const ssid = root.pendingSsid
      if (exitCode === 0) {
        root.closeLauncher()
        root.pendingSsid = ""
        return
      }
      root.startPrompt("Password for " + ssid,
        "Connection failed" + (root._lastErr ? ": " + root._lastErr : ""))
      root._lastErr = ""
    }
  }
}
