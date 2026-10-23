import QtQuick
import Quickshell
import "../components"
import qs

LauncherBase {
  id: root

  sockName: "kmdot-connections"
  castStyle: true
  title: "Connections"
  searchPlaceholder: "Search connections…"
  headerTitle: "Connections"
  cardHeight: 520
  footerHint: "\u2191\u2193 navigate \u00b7 \u23ce open"
  countShown: false

  // The command hub searches these items before this launcher is ever opened.
  Component.onCompleted: root.refreshItems()

  function refreshItems() {
    const wifiSubtitle = Wifi.connectedSsid
      ? Wifi.connectedSsid + " · Connected"
      : (Wifi.scanning ? "Scanning for networks…" : (Wifi.enabled ? "Not connected" : "Wi-Fi off"))
    let bluetoothDevice = ""
    for (const d of BluetoothStore.devices) {
      if (d.connected) { bluetoothDevice = d.name; break }
    }
    const bluetoothSubtitle = bluetoothDevice
      ? bluetoothDevice + " · Connected"
      : (!BluetoothStore.adapter ? "No adapter"
        : !BluetoothStore.enabled ? "Bluetooth off"
        : BluetoothStore.discovering ? "Scanning for devices…" : "Not connected")

    root.items = [
      { label: "Wi-Fi", subtitle: wifiSubtitle, glyph: "\uf1eb", action: "wifi" },
      { label: "Bluetooth", subtitle: bluetoothSubtitle, glyph: "\uf293", action: "bluetooth" }
    ]
    root.pool = root.items
  }

  function onOpenedChange() {
    if (!root.opened) {
      BluetoothStore.stopDiscovery()
      return
    }
    Wifi.scan()
    BluetoothStore.refresh()
    if (BluetoothStore.enabled) BluetoothStore.startDiscovery()
    root.refreshItems()
  }

  Connections {
    target: Wifi
    function onConnectedSsidChanged() { root.refreshItems() }
    function onScanningChanged() { root.refreshItems() }
    function onEnabledChanged() { root.refreshItems() }
  }

  Connections {
    target: BluetoothStore
    function onDevicesChanged() { root.refreshItems() }
    function onEnabledChanged() { root.refreshItems() }
    function onDiscoveringChanged() { root.refreshItems() }
  }

  onActivated: function(item) {
    if (item.action === "bluetooth") root.scope.bluetoothLauncher.openLauncher()
    else if (item.action === "wifi") root.scope.wifiLauncher.openLauncher()
  }
}
