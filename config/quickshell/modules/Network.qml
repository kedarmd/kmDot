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
    : (disabled ? "Wi-Fi disabled" : "Wi-Fi on · Not connected")

  glyph: ""
  iconName: {
    // A wired link remains the active network path even when the Wi-Fi radio
    // is disabled; don't show the Wi-Fi-off marker for an Ethernet connection.
    if (wiredConnected()) return "ethernet"
    if (disabled) return "wifi-off"
    if (net) {
      // Quickshell exposes this as a percentage on current releases, while
      // older versions returned a 0..1 fraction. Normalize both forms first.
      var s = Number(net.signalStrength)
      if (s > 1) s /= 100
      // Keep one consistent Wi-Fi glyph; the success color signals connection.
      return "wifi"
    }
    return "wifi-on"
  }
  active: false
  iconForeground: root.connected ? Colors.success : Colors.primary_alt
  fill: Tokens.primaryContainer
  on_color: Tokens.on_primary_container
  dimmed: disabled
}
