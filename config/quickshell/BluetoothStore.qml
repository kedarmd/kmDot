pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import "components/bluetooth.js" as BtJs

// Single owner for all BlueZ radio state (issue #61; `Bluetooth` is taken by
// the Quickshell.Bluetooth service, hence BluetoothStore).
// Owns the device inventory, the pair-then-connect escalation, the 15s busy
// timeout, and discovery/enabled control behind one small interface; the
// Dropdown, Launcher, and AddPopup are thin adapters that keep rendering
// plus intent and bind here for everything else.
Singleton {
  id: root

  readonly property var adapter: Bluetooth.defaultAdapter
  readonly property bool enabled: !!root.adapter && root.adapter.enabled
  readonly property bool discovering: !!root.adapter && root.adapter.discovering
  // Mapped entries: { device, path, name, connected, paired, pairing, icon
  // (glyph), battery (int percent, -1 when unavailable), batteryAvailable }.
  // Sorted connected-first, then paired, then name.
  property var devices: []
  property string busyPath: ""
  // "pair", "connect", or "disconnect" while an operation is in flight.
  property string busyAction: ""
  property string errorText: ""

  // Devices whose signals are already wired (stable QObjects).
  property var _wired: []

  function setEnabled(on) {
    if (root.adapter) root.adapter.enabled = !!on
  }

  function startDiscovery() {
    if (root.adapter && root.adapter.enabled) root.adapter.discovering = true
  }

  function stopDiscovery() {
    if (root.adapter) root.adapter.discovering = false
  }

  function _wire(d) {
    if (root._wired.indexOf(d) >= 0) return
    d.connectedChanged.connect(root.refresh)
    d.pairedChanged.connect(root.refresh)
    d.pairingChanged.connect(root.refresh)
    d.nameChanged.connect(root.refresh)
    try { d.stateChanged.connect(root.refresh) } catch (e) {}
    try { d.batteryChanged.connect(root.refresh) } catch (e) {}
    try { d.batteryAvailableChanged.connect(root.refresh) } catch (e) {}
    root._wired = root._wired.concat(d)
  }

  function refresh() {
    let values = []
    if (Bluetooth.devices) {
      try {
        values = Bluetooth.devices.values
      } catch (e) {
        values = []
      }
    }
    const stillPresent = {}
    const out = []
    for (const d of values) {
      let name, connected, paired, pairing, glyph, battery, batteryAvailable, path
      try {
        name = String(d.name || "").trim()
        if (!name) continue
        path = d.dbusPath || ""
        connected = !!d.connected
        paired = !!d.paired
        pairing = !!d.pairing
        glyph = BtJs.deviceGlyph(d.icon)
        batteryAvailable = !!d.batteryAvailable
        battery = batteryAvailable ? Math.round(Number(d.battery) * 100) : -1
        if (!isFinite(battery)) { battery = -1; batteryAvailable = false }
        root._wire(d)
      } catch (e) {
        // Device removed mid-iteration (e.g. adapter powered off deletes the
        // QObject) — skip it and keep the rest of the list intact.
        continue
      }
      if (path) stillPresent[path] = true
      out.push({
        device: d, path: path, name: name, connected: connected,
        paired: paired, pairing: pairing, icon: glyph, battery: battery,
        batteryAvailable: batteryAvailable
      })
      // Pair-to-auto-connect escalation (single copy; the three per-view
      // copies are deleted): a pair that bonded escalates to connect, and
      // terminal states settle or fail the busy operation.
      if (path !== "" && path === root.busyPath) {
        if (root.busyAction === "pair" && paired) {
          try {
            d.connect()
            root.busyAction = "connect"
          } catch (e) {
            root.errorText = String(e)
            root.busyPath = ""
            root.busyAction = ""
            busyTimer.stop()
          }
        } else if (root.busyAction === "connect" && connected) {
          root.busyPath = ""
          root.busyAction = ""
          busyTimer.stop()
        } else if (root.busyAction === "disconnect" && !connected) {
          root.busyPath = ""
          root.busyAction = ""
          busyTimer.stop()
        } else if (root.busyAction === "pair" && !pairing && !paired) {
          root.errorText = "Pairing failed"
          root.busyPath = ""
          root.busyAction = ""
          busyTimer.stop()
        }
      }
    }
    root._wired = root._wired.filter(function(w) {
      try {
        return w.dbusPath && stillPresent[w.dbusPath]
      } catch (e) {
        return false
      }
    })
    root.devices = BtJs.sortDevices(out)
  }

  // The pair-to-auto-connect escalation lives inside: unpaired entries pair
  // and auto-connect once bonded (see refresh); paired entries connect and
  // connected entries disconnect.
  function activate(entry) {
    if (!entry || !entry.device || !root.enabled) return
    const d = entry.device
    const path = entry.path || ""
    root.busyPath = path
    root.busyAction = entry.connected ? "disconnect" : (entry.paired ? "connect" : "pair")
    root.errorText = ""
    try {
      if (entry.connected) d.disconnect()
      else if (entry.paired) d.connect()
      else d.pair()
    } catch (e) {
      root.errorText = String(e)
      root.busyPath = ""
      root.busyAction = ""
      busyTimer.stop()
      return
    }
    if (root.busyPath) busyTimer.restart()
  }

  function forget(path) {
    if (!path || !root.enabled) return
    const entry = root.devices.find(function(e) { return e.path === path })
    if (!entry || !entry.device || (!entry.paired && !entry.connected)) return
    try {
      if (entry.connected) entry.device.disconnect()
      entry.device.forget()
      busyTimer.stop()
      root.busyPath = ""
      root.busyAction = ""
      root.errorText = ""
    } catch (e) {
      root.errorText = String(e)
    }
    root.refresh()
  }

  Component.onCompleted: root.refresh()

  Connections {
    target: Bluetooth
    function onDefaultAdapterChanged() { root.refresh() }
  }

  Connections {
    target: root.adapter
    function onDiscoveringChanged() {
      // Bluetooth.devices is an UntypedObjectModel without a count signal;
      // discovery transitions are the reliable inventory refresh boundary.
      root.refresh()
    }
    function onEnabledChanged() {
      // Adapter switched off: stop discovery and drop any in-flight operation.
      if (root.adapter && !root.adapter.enabled) {
        if (root.adapter.discovering) root.adapter.discovering = false
        busyTimer.stop()
        root.busyPath = ""
        root.busyAction = ""
        root.errorText = ""
      }
      root.refresh()
    }
  }

  Timer {
    id: busyTimer
    interval: 15000
    repeat: false
    onTriggered: {
      if (!root.busyPath) return
      root.errorText = "Bluetooth operation timed out"
      root.busyPath = ""
      root.busyAction = ""
    }
  }
}
