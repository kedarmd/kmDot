import QtQuick
import Quickshell.Bluetooth
import Quickshell.Io
import qs

Item {
  id: root
  implicitHeight: 30
  width: label.implicitWidth + 20
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

  Text {
    id: label
    anchors.centerIn: parent
    text: root.btEnabled ? "󰂯" : "󰂲"
    font.family: "JetBrainsMono Nerd Font Propo"
    font.pixelSize: 14
    color: root.connectedCount > 0 ? Colors.text : Colors.text_alt
    opacity: root.btEnabled ? 1.0 : 0.4
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    onClicked: {
      if (mouse.button === Qt.RightButton) {
        if (root.adapter) root.adapter.enabled = !root.adapter.enabled
        root.refresh()
      } else {
        managerProc.exec(["blueman-manager"])
      }
    }
    onEntered: root.tooltip.show(root, root.tooltipText)
    onExited: root.tooltip.hide()
  }

  Process {
    id: managerProc
  }
}
