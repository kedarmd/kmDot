import QtQuick
import Quickshell
import "../components"
import qs

LauncherBase {
  id: root

  sockName: "kmdot-connections"
  title: "Connections"
  footerHint: "\u2191\u2193 navigate \u00b7 \u23ce open \u00b7 esc close"

  items: [
    { label: "Bluetooth", glyph: "\uf293", action: "bluetooth" },
    { label: "Wi-Fi", glyph: "\uf1eb", action: "wifi" }
  ]

  onActivated: function(item) {
    if (item.action === "bluetooth") root.scope.bluetoothLauncher.openLauncher()
    else if (item.action === "wifi") root.scope.wifiLauncher.openLauncher()
  }
}
