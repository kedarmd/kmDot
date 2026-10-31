import QtQuick
import Quickshell
import "../components"
import "../components/nerdicons.js" as NerdIcons
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
    const wifiSubtitle = !Wifi.enabled ? "Wi-Fi off"
      : Wifi.connectedSsid ? Wifi.connectedSsid + " · Connected"
      : (Wifi.scanning ? "Scanning for networks…" : "Not connected")
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
      { label: "Wi-Fi", subtitle: wifiSubtitle, glyph: NerdIcons.glyph(!Wifi.enabled ? "wifi-off" : "wifi"), action: "wifi" },
      { label: "Bluetooth", subtitle: bluetoothSubtitle, glyph: NerdIcons.glyph(!BluetoothStore.enabled ? "bluetooth-off" : bluetoothDevice ? "bluetooth-connected" : "bluetooth-on"), action: "bluetooth" }
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
