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

  glyph: ""
  iconName: {
    if (disabled) return "wifi-disabled"
    if (wiredConnected()) return "wifi"
    if (!net) return "wifi-off"
    // Quickshell exposes this as a percentage on current releases, while
    // older versions returned a 0..1 fraction. Normalize both forms before
    // applying the icon thresholds.
    var s = Number(net.signalStrength)
    if (s > 1) s /= 100
    if (s <= 0.25) return "wifi-low"
    if (s <= 0.5) return "wifi-medium"
    return "wifi"
  }
  active: false
  fill: Tokens.primaryContainer
  on_color: Tokens.on_primary_container
  dimmed: disabled
}
