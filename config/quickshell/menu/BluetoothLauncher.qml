import QtQuick
import Quickshell
import Quickshell.Bluetooth
import "../components"
import qs

LauncherBase {
  id: root

  sockName: "kmdot-bluetooth"
  title: "Bluetooth"
  footerHint: "\u2191\u2193 navigate \u00b7 \u23ce connect/disconnect \u00b7 tab toggle \u00b7 esc close"
  countShown: false
  loadingText: "Scanning for devices..."
  // Pairing keeps the launcher open; connect/disconnect close it explicitly.
  closeOnActivate: false

  readonly property var adapter: Bluetooth.defaultAdapter

  // Devices whose signals we've already wired (device objects are stable QObjects).
  property var _wired: []
  // Devices we asked to pair — auto-connect them once pairing completes.
  property var _pairInFlight: []

  function deviceGlyph(icon) {
    switch (root.toStr(icon).toLowerCase()) {
      case "input-keyboard": return "\uf11c"
      case "input-mouse":
      case "input-tablet": return "\uf245"
      case "audio-headset":
      case "audio-headphones":
      case "audio-card": return "\uf025"
      case "phone":
      case "smartphone": return "\uf10b"
      case "computer":
      case "laptop": return "\uf109"
      case "video-display":
      case "tv": return "\uf26c"
      default: return "\uf293"
    }
  }

  function syncFooter() {
    const on = root.adapter ? root.adapter.enabled : false
    root.footerActionGlyph = on ? "\uf293" : "\uf011"
    root.footerActionText = on ? "Bluetooth On" : "Bluetooth Off"
    root.footerActionActive = on
  }

  function wireDevice(d) {
    if (root._wired.indexOf(d) >= 0) return
    d.connectedChanged.connect(root.rebuild)
    d.pairedChanged.connect(root.rebuild)
    d.pairingChanged.connect(root.rebuild)
    d.nameChanged.connect(root.rebuild)
    d.stateChanged.connect(root.rebuild)
    d.batteryChanged.connect(root.rebuild)
    d.batteryAvailableChanged.connect(root.rebuild)
    root._wired.push(d)
  }

  function refreshItems() {
    root.rebuild()
  }

  function onOpenedChange() {
    if (!root.adapter) return
    if (root.opened) {
      if (root.adapter.enabled) discoveryTimer.start()
    } else {
      discoveryTimer.stop()
      root.adapter.discovering = false
    }
  }

  function rebuild() {
    const adapter = root.adapter
    let values = []
    if (Bluetooth.devices) {
      try {
        values = Bluetooth.devices.values
      } catch (e) {
        values = []
      }
    }
    const stillPresent = {}
    let items = []
    for (const d of values) {
      let name, dConnected, dPairing, dPaired, dBattery, dIcon, dPath
      try {
        name = root.toStr(d.name || d.deviceName).trim()
        dConnected = d.connected
        dPairing = d.pairing
        dPaired = d.paired
        dBattery = d.batteryAvailable ? " \u00b7 " + Math.round(d.battery * 100) + "%" : ""
        dIcon = d.icon
        dPath = d.dbusPath || ""
        root.wireDevice(d)
      } catch (e) {
        // Device removed mid-iteration (e.g. adapter powered off deletes the
        // QObject) — skip it and keep the rest of the list intact.
        continue
      }
      if (dPath) stillPresent[dPath] = true
      if (!name) continue
      let subtitle
      if (dConnected) subtitle = "Connected" + dBattery
      else if (dPairing) subtitle = "Pairing\u2026"
      else if (dPaired) subtitle = "Paired" + dBattery
      else subtitle = "Not paired"
      const inFlight = root._pairInFlight.indexOf(dPath)
      if (inFlight >= 0) {
        if (dPaired) {
          try { d.connect() } catch (e) {}
          root._pairInFlight = root._pairInFlight.filter(function(p) { return p !== dPath })
        } else if (!dPairing) {
          // Pairing ended without bonding (failed/cancelled) — drop the follow-up.
          root._pairInFlight = root._pairInFlight.filter(function(p) { return p !== dPath })
        }
      }
      items.push({
        label: name,
        subtitle: subtitle,
        glyph: root.deviceGlyph(dIcon),
        device: d,
        connected: dConnected,
        paired: dPaired
      })
    }
    // Drop signal wires for devices that are no longer in the model.
    root._wired = root._wired.filter(function(w) {
      return w.dbusPath && stillPresent[w.dbusPath]
    })
    items.sort(function(a, b) {
      return (b.connected ? 1 : 0) - (a.connected ? 1 : 0)
        || (b.paired ? 1 : 0) - (a.paired ? 1 : 0)
    })
    root.syncFooter()
    const enabled = adapter ? adapter.enabled : false
    // Match wifi: hide the device list while off so the "Bluetooth is turned off"
    // empty state shows (activating a device with the radio off would fail silently).
    if (!enabled) items = []
    root.loading = enabled && !!adapter && adapter.discovering && items.length === 0
    root.emptyText = !adapter ? "No Bluetooth adapter"
      : !enabled ? "Bluetooth is turned off"
      : "No devices found"
    root.pool = items
  }

  Connections {
    target: Bluetooth
    function onDefaultAdapterChanged() { root.rebuild() }
  }

  Connections {
    target: root.adapter
    function onEnabledChanged() { root.rebuild() }
    function onDiscoveringChanged() { root.rebuild() }
  }

  Timer {
    id: discoveryTimer
    interval: 250
    repeat: false
    onTriggered: {
      if (root.adapter && root.adapter.enabled) root.adapter.discovering = true
    }
  }

  onActivated: function(item) {
    const d = item.device
    if (!d) return
    if (item.connected) {
      root.closeLauncher()
      d.disconnect()
    } else if (item.paired) {
      root.closeLauncher()
      d.connect()
    } else {
      if (!d.pairing) {
        root._pairInFlight = root._pairInFlight.concat(d.dbusPath)
        d.pair()
      }
    }
  }

  onFooterActionClicked: {
    if (!root.adapter) return
    root.adapter.enabled = !root.adapter.enabled
    root.syncFooter()
    root.rebuild()
    if (root.adapter.enabled && root.opened) discoveryTimer.start()
  }
}
