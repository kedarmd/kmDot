import QtQuick
import Quickshell.Networking
import Quickshell.Io
import qs
import "../components"

Item {
  id: root
  implicitHeight: 30
  width: Math.max(30, label.implicitWidth + 20)
  required property var tooltip

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
  readonly property string tooltipText: connected
    ? ("Connected to: " + (net ? net.name : "Wired Connection"))
    : (disabled ? "Wi-Fi disabled" : "Disconnected")

  readonly property string icon: {
    if (disabled) return "󰤮"
    if (wiredConnected()) return "󰈁"
    if (!net) return "󰤯"
    var s = net.signalStrength
    if (s <= 0.25) return "󰤟"
    if (s <= 0.5) return "󰤢"
    if (s <= 0.75) return "󰤥"
    return "󰤨"
  }

  ModulePill {
    id: pill
    anchors.centerIn: parent
    width: Math.max(30, label.implicitWidth + 20)
    height: 30
    active: root.connected && !root.disabled
    fill: Tokens.primaryContainer
    hovered: mouse.containsMouse
    pressed: mouse.pressed

    Text {
      id: label
      anchors.centerIn: parent
      text: icon
      font.family: "JetBrainsMono Nerd Font Propo"
      font.pixelSize: 15
      color: root.connected && !root.disabled ? Tokens.on_primary_container : Colors.text_alt
      opacity: root.disabled ? 0.4 : 1.0
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    onClicked: {
      if (mouse.button === Qt.RightButton) {
        Networking.wifiEnabled = !Networking.wifiEnabled
      } else {
        wifiProc.exec(["sh", "-c", "$HOME/.config/kmdot/quickshell/scripts/toggle.sh kmdot-wifi-dropdown"])
      }
    }
    onEntered: root.tooltip.show(root, root.tooltipText)
    onExited: root.tooltip.hide()
  }

  Process {
    id: wifiProc
  }
}
