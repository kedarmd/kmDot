import QtQuick
import Quickshell.Bluetooth
import Quickshell.Io
import qs
import "../components"

Item {
  id: root
  implicitHeight: 30
  width: Math.max(30, label.implicitWidth + 20)
  required property var tooltip

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

  readonly property string tooltipText: {
    if (connectedCount > 0) {
      var names = []
      for (const d of Bluetooth.devices.values) {
        if (d.connected) names.push(d.name)
      }
      return "Bluetooth: " + connectedCount + " connected\n" + names.join("\n")
    }
    return "Bluetooth: " + (btEnabled ? "on" : "off")
  }

  ModulePill {
    id: pill
    anchors.centerIn: parent
    width: Math.max(30, label.implicitWidth + 20)
    height: 30
    active: root.btEnabled && root.connectedCount > 0
    fill: Tokens.primaryContainer
    hovered: mouse.containsMouse
    pressed: mouse.pressed

    Text {
      id: label
      anchors.centerIn: parent
      text: root.btEnabled ? "󰂯" : "󰂲"
      font.family: "JetBrainsMono Nerd Font Propo"
      font.pixelSize: 14
      color: root.btEnabled && root.connectedCount > 0 ? Tokens.on_primary_container : Colors.text_alt
      opacity: root.btEnabled ? 1.0 : 0.4
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
        if (root.adapter) root.adapter.enabled = !root.adapter.enabled
        root.refresh()
      } else {
        toggleProc.exec(["sh", "-c", "$HOME/.config/kmdot/quickshell/scripts/toggle.sh kmdot-bluetooth"])
      }
    }
    onEntered: root.tooltip.show(root, root.tooltipText)
    onExited: root.tooltip.hide()
  }

  Process {
    id: toggleProc
  }
}
