pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "components/wifi.js" as WifiJs

// Single owner for all nmcli wifi radio state (issue #61).
// Owns the scan/parse/connect/disconnect/toggle/forget machine behind one
// small interface; the Dropdown, Launcher, and AddPopup are thin adapters
// that keep rendering plus intent and bind here for everything else.
// Single-proc scan via the SAVED + ACTIVE_CONN sentinel path (the dedicated
// second savedProc is deleted). One empty-retry policy lives in scan():
// while enabled and empty, up to 2 rescans at 2.5s (replaces the Dropdown
// settleTimer, the launcher empty-rescan, and the radio-toggle refresh).
// Bar modules stay native-first with no store bind.
Singleton {
  id: root

  property bool enabled: false
  property bool scanning: false
  // Entries: { ssid, signal, security, active, saved, open }
  // Sorted active-first, then signal desc.
  property var networks: []
  property string connectedSsid: ""
  property var savedNames: []
  property string busySsid: ""
  // "connect" or "disconnect" while an action is in flight.
  property string busyAction: ""
  property string errorText: ""

  // Raw scan accumulators for the single scanProc below.
  property var _rows: []
  property var _savedLines: []
  property var _activeLines: []
  property bool _savedMode: false
  property bool _activeMode: false
  property int _emptyScans: 0
  property string _actionOut: ""

  function isSaved(ssid) {
    return root.savedNames.indexOf(ssid) >= 0
  }

  // Explicit user-initiated scan: resets the empty-retry budget.
  function scan() {
    root._emptyScans = 0
    root._runScan()
  }

  function _runScan() {
    root.scanning = true
    root.networks = []
    root.connectedSsid = ""
    root.savedNames = []
    root._rows = []
    root._savedLines = []
    root._activeLines = []
    root._savedMode = false
    root._activeMode = false
    scanProc.exec(["sh", "-c",
      "nmcli -t -f ACTIVE,SSID,SIGNAL,SECURITY device wifi list 2>/dev/null; " +
      "printf 'STATE:%s\\n' \"$(nmcli -t -f WIFI general 2>/dev/null)\"; " +
      "printf 'SAVED\\n'; nmcli -t -f NAME,TYPE connection show 2>/dev/null; " +
      "printf 'ACTIVE_CONN\\n'; nmcli -t -f NAME,TYPE connection show --active 2>/dev/null"])
  }

  function _buildNetworks() {
    const saved = []
    for (const line of root._savedLines) {
      const name = WifiJs.parseSavedLine(line)
      if (name && saved.indexOf(name) < 0) saved.push(name)
    }
    root.savedNames = saved

    let connected = ""
    for (const line of root._activeLines) {
      const name = WifiJs.parseActiveLine(line)
      if (name) { connected = name; break }
    }
    root.connectedSsid = connected

    const out = []
    const seen = {}
    for (const line of root._rows) {
      const net = WifiJs.parseScanLine(line)
      if (!net) continue
      net.saved = saved.indexOf(net.ssid) >= 0
      if (net.ssid === connected) net.active = true
      if (seen[net.ssid]) {
        for (let i = 0; i < out.length; i++) {
          if (out[i].ssid === net.ssid) { out[i] = net; break }
        }
      } else {
        seen[net.ssid] = true
        out.push(net)
      }
    }
    if (connected && !seen[connected]) {
      out.push({
        ssid: connected, active: true, signal: 0, open: false,
        security: "Connected", saved: saved.indexOf(connected) >= 0
      })
    }
    root.networks = WifiJs.sortNetworks(out)
    root.scanning = false
    // One settle/retry policy: right after the radio is re-enabled the
    // device may not have cached any APs yet, so an empty scan retries.
    if (root.enabled && root.networks.length === 0 && root._emptyScans < 2) {
      root._emptyScans++
      rescanTimer.restart()
    }
  }

  // Connect a network. Returns false when a secured unsaved network needs a
  // password first (the caller prompts and retries with one); otherwise the
  // action runs and busy/error/scan settle through the store.
  function connect(net, password) {
    if (!net || !net.ssid || root.busySsid !== "") return true
    if (net.active) return true
    const ssid = net.ssid
    const saved = !!(net.saved || root.isSaved(ssid))
    const open = net.open !== undefined ? !!net.open : WifiJs.isOpen(net.security)
    const pass = password !== undefined ? String(password) : ""
    if (!open && !saved && !pass) return false
    root.busySsid = ssid
    root.busyAction = "connect"
    root.errorText = ""
    root._actionOut = ""
    let cmd
    if (pass) {
      cmd = saved
        ? "nmcli connection modify id " + WifiJs.shellQuote(ssid) + " wifi-sec.psk " + WifiJs.shellQuote(pass) + " && nmcli connection up id " + WifiJs.shellQuote(ssid)
        : "nmcli dev wifi connect " + WifiJs.shellQuote(ssid) + " password " + WifiJs.shellQuote(pass)
    } else {
      cmd = open
        ? "nmcli dev wifi connect " + WifiJs.shellQuote(ssid)
        : "nmcli connection up id " + WifiJs.shellQuote(ssid)
    }
    actionProc.exec(["sh", "-c", cmd + " 2>&1"])
    return true
  }

  function disconnect(net) {
    if (!net || !net.ssid || root.busySsid !== "") return
    root.busySsid = net.ssid
    root.busyAction = "disconnect"
    root.errorText = ""
    root._actionOut = ""
    actionProc.exec(["sh", "-c", "nmcli con down id " + WifiJs.shellQuote(net.ssid) + " 2>&1"])
  }

  function toggleRadio() {
    radioProc.exec(["sh", "-c", "nmcli radio wifi " + (root.enabled ? "off" : "on")])
  }

  function forget(ssid) {
    if (!ssid) return
    root.errorText = ""
    forgetProc.exec(["sh", "-c", "nmcli connection delete id " + WifiJs.shellQuote(ssid)])
  }

  Component.onCompleted: root.scan()

  Timer {
    id: rescanTimer
    interval: 2500
    repeat: false
    onTriggered: root._runScan()
  }

  Process {
    id: scanProc
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function(data) {
        const line = String(data)
        if (line.startsWith("STATE:")) {
          root.enabled = line.slice(6).trim() === "enabled"
          return
        }
        if (line === "SAVED") { root._savedMode = true; root._activeMode = false; return }
        if (line === "ACTIVE_CONN") { root._activeMode = true; root._savedMode = false; return }
        if (root._activeMode) { root._activeLines.push(line); return }
        if (root._savedMode) { root._savedLines.push(line); return }
        root._rows.push(line)
      }
    }
    onExited: root._buildNetworks()
  }

  Process {
    id: actionProc
    stdout: StdioCollector { onStreamFinished: root._actionOut = String(this.text).trim() }
    onExited: function(code) {
      if (code !== 0) root.errorText = root._actionOut || "Connection failed"
      else root.errorText = ""
      root.busySsid = ""
      root.busyAction = ""
      root._runScan()
    }
  }

  Process {
    id: radioProc
    onExited: root._runScan()
  }

  Process {
    id: forgetProc
    onExited: {
      root.errorText = ""
      root._runScan()
    }
  }
}
