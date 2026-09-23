import QtQuick
import Quickshell.Networking
import qs
import "../components"

BarModule {
  id: root
  sock: "kmdot-wifi-dropdown"

  function wifiDevice() {
    for (const d of Networking.devices.values) {
      if (d.type === DeviceType.Wifi) return d
    }
    return null
  }

  function connectedWifi() {
    var dev = wifiDevice()
    if (!dev) return null
    for (const n of dev.networks.values) {
      if (n.connected) return n
    }
    return null
  }

  function wiredConnected() {
    for (const d of Networking.devices.values) {
      if (d.type === DeviceType.Wired && d.connected) return true
    }
    return false
  }

  readonly property var net: connectedWifi()
  readonly property bool disabled: !Networking.wifiHardwareEnabled || !Networking.wifiEnabled
  readonly property bool connected: !!net || wiredConnected()

  tooltipText: connected
    ? ("Connected to: " + (net ? net.name : "Wired Connection"))
    : (disabled ? "Wi-Fi disabled" : "Disconnected")

  glyph: {
    if (disabled) return "󰤮"
    if (wiredConnected()) return "󰈁"
    if (!net) return "󰤯"
    var s = net.signalStrength
    if (s <= 0.25) return "󰤟"
    if (s <= 0.5) return "󰤢"
    if (s <= 0.75) return "󰤥"
    return "󰤨"
  }
  active: connected && !disabled
  fill: Tokens.primaryContainer
  on_color: Tokens.on_primary_container
  dimmed: disabled
}
