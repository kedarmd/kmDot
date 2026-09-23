import QtQuick
import Quickshell
import "../components"
import "../components/bluetooth.js" as BtJs
import qs

LauncherBase {
  id: root

  sockName: "kmdot-bluetooth"
  title: "Bluetooth"
  footerHint: "↑↓ navigate · ⏎ connect/disconnect · tab toggle · esc close"
  countShown: false
  loadingText: "Scanning for devices..."
  // Pairing keeps the launcher open; connect/disconnect close it explicitly.
  closeOnActivate: false

  // Thin adapter over the BluetoothStore singleton (issue #61): the pool
  // derives from the shared devices list; this view keeps pool derivation,
  // activate intent, and the footer pill only.
  readonly property var adapter: BluetoothStore.adapter

  function batterySuffix(d) {
    return BtJs.batteryLabel(d.batteryAvailable, d.battery)
  }

  function syncFooter() {
    const on = BluetoothStore.enabled
    root.footerActionGlyph = on ? "" : ""
    root.footerActionText = on ? "Bluetooth On" : "Bluetooth Off"
    root.footerActionActive = on
  }

  function refreshItems() {
    BluetoothStore.errorText = ""
    BluetoothStore.refresh()
    root.rebuild()
  }

  function onOpenedChange() {
    if (!root.opened) {
      BluetoothStore.stopDiscovery()
      return
    }
    BluetoothStore.errorText = ""
    BluetoothStore.refresh()
    if (BluetoothStore.enabled) BluetoothStore.startDiscovery()
    root.rebuild()
  }

  function rebuild() {
    const enabled = BluetoothStore.enabled
    let items = []
    for (const d of BluetoothStore.devices) {
      let subtitle
      if (d.connected) subtitle = "Connected" + root.batterySuffix(d)
      else if (d.pairing || (BluetoothStore.busyPath === d.path && BluetoothStore.busyAction === "pair")) subtitle = "Pairing…"
      else if (d.paired) subtitle = "Paired" + root.batterySuffix(d)
      else subtitle = "Not paired"
      if (BluetoothStore.busyPath === d.path && BluetoothStore.busyAction === "connect") subtitle = "Connecting…"
      else if (BluetoothStore.busyPath === d.path && BluetoothStore.busyAction === "disconnect") subtitle = "Disconnecting…"
      items.push({
        label: d.name,
        subtitle: subtitle,
        glyph: d.icon,
        device: d.device,
        path: d.path,
        connected: !!d.connected,
        paired: !!d.paired
      })
    }
    // BluetoothStore.devices arrives sorted from the store; keep that order.
    // Match the dropdown gate: hide the device list while off so the
    // "Bluetooth is turned off" empty state shows.
    if (!enabled) items = []
    root.syncFooter()
    root.loading = enabled && BluetoothStore.discovering && items.length === 0
    root.emptyText = !root.adapter ? "No Bluetooth adapter"
      : !enabled ? "Bluetooth is turned off"
      : "No devices found"
    root.pool = items
  }

  Connections {
    target: BluetoothStore
    function onDevicesChanged() { root.rebuild() }
    function onEnabledChanged() {
      root.rebuild()
      if (BluetoothStore.enabled && root.opened) BluetoothStore.startDiscovery()
    }
    function onDiscoveringChanged() { root.rebuild() }
    function onBusyPathChanged() { root.rebuild() }
    function onBusyActionChanged() { root.rebuild() }
  }

  onActivated: function(item) {
    const entry = BluetoothStore.devices.find(function(e) { return e.path === item.path })
    if (!entry) return
    if (item.connected || item.paired) {
      root.closeLauncher()
      BluetoothStore.activate(entry)
    } else {
      BluetoothStore.activate(entry)
    }
  }

  onFooterActionClicked: {
    BluetoothStore.setEnabled(!BluetoothStore.enabled)
    root.syncFooter()
    root.rebuild()
  }
}
