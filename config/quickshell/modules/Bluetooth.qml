import QtQuick
import Quickshell.Bluetooth
import qs
import "../components"

BarModule {
  id: root
  sock: "kmdot-bluetooth-dropdown"

  readonly property var adapter: Bluetooth.defaultAdapter

  property bool btEnabled: false
  property int connectedCount: 0

  function refresh() {
    root.btEnabled = root.adapter ? root.adapter.enabled : false
    var c = 0
    if (Bluetooth.devices) {
      for (const d of Bluetooth.devices.values) {
        if (d.connected) c++
      }
    }
    root.connectedCount = c
  }

  onAdapterChanged: root.refresh()
  Timer {
    interval: 2000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }
  Component.onCompleted: root.refresh()

  tooltipText: {
    if (connectedCount > 0) {
      var names = []
      for (const d of Bluetooth.devices.values) {
        if (d.connected) names.push(d.name)
      }
      return "Bluetooth: " + connectedCount + " connected\n" + names.join("\n")
    }
    return "Bluetooth: " + (btEnabled ? "on" : "off")
  }

  glyph: root.btEnabled ? "󰂯" : "󰂲"
  active: root.btEnabled && root.connectedCount > 0
  fill: Tokens.primaryContainer
  on_color: Tokens.on_primary_container
  dimmed: !root.btEnabled
}
