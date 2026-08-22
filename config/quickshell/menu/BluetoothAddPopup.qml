import QtQuick
import Quickshell.Bluetooth
import qs
import "../components"

ConnectionDropdownBase {
  id: root
  title: "Pair Bluetooth device"
  cardWidth: 360
  escapeCloses: true
  socketEnabled: false

  property var devices: []
  property var wired: []
  property string busyPath: ""
  property string busyAction: ""
  property string resultText: ""
  // Parent dropdown gates everything on the adapter being enabled.
  readonly property bool radioAllowed: {
    const d = root.scope && root.scope.bluetoothDropdown ? root.scope.bluetoothDropdown : null
    return !!d && d.radioEnabled
  }

  function refreshItems() {
    const values = Bluetooth.devices ? Bluetooth.devices.values : []
    root.devices = values
    for (const d of values) {
      if (root.wired.indexOf(d) < 0) {
        d.pairedChanged.connect(root.refreshItems)
        d.connectedChanged.connect(root.refreshItems)
        root.wired = root.wired.concat(d)
      }
      if (root.busyPath === (d.dbusPath || "") && root.busyAction === "pair" && d.paired) {
        try { d.connect(); root.busyAction = "connect"; root.resultText = "Connecting to " + d.name + "..." } catch (e) { root.busyPath = ""; root.busyAction = ""; root.resultText = String(e); busyTimer.stop() }
      } else if (root.busyPath === (d.dbusPath || "") && root.busyAction === "connect" && d.connected) {
        root.busyPath = ""
        root.busyAction = ""
        busyTimer.stop()
        root.resultText = "Connected to " + d.name
      } else if (root.busyPath === (d.dbusPath || "") && !d.pairing && !d.paired) {
        root.busyPath = ""
        root.busyAction = ""
        busyTimer.stop()
        root.resultText = "Pairing failed"
      }
    }
    if (root.radioAllowed) Bluetooth.defaultAdapter.discovering = true
  }
  function activate(d) {
    if (!root.radioAllowed) return
    root.busyPath = d.dbusPath || ""
    root.busyAction = "pair"
    root.resultText = "Pairing with " + d.name + "..."
    try { d.pair(); busyTimer.restart() } catch (e) { root.busyPath = ""; root.busyAction = ""; root.resultText = String(e) }
  }
  function openedChange() {
    if (root.opened) {
      // Never pair into a powered-off adapter: bounce straight back out.
      if (!root.radioAllowed) { root.close(); return }
      root.refreshItems()
      return
    }
    busyTimer.stop()
    root.busyPath = ""
    root.busyAction = ""
    root.resultText = ""
    if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.discovering = false
  }

  Connections { target: Bluetooth; function onDefaultAdapterChanged() { root.refreshItems() } }
  Connections { target: root.adapter; function onDiscoveringChanged() { root.refreshItems() } }
  Connections {
    id: bluetoothRadioWatch
    target: root.scope && root.scope.bluetoothDropdown ? root.scope.bluetoothDropdown : null
    // Bluetooth switched off while the pairing popup is open → close it.
    function onRadioEnabledChanged() {
      if (bluetoothRadioWatch.target && !bluetoothRadioWatch.target.radioEnabled && root.opened) root.close()
    }
  }
  readonly property var adapter: Bluetooth.defaultAdapter

  Timer {
    id: busyTimer
    interval: 15000
    repeat: false
    onTriggered: {
      root.busyPath = ""
      root.busyAction = ""
      root.resultText = "Pairing timed out"
    }
  }

  Column {
    width: parent.width; spacing: 12
    Row { width: parent.width; spacing: 10
      PillButton { id: backButton; width: 30; filled: true; glyph: "\uf060"; onClicked: { root.close(); if (root.scope && root.scope.bluetoothDropdown) root.scope.bluetoothDropdown.open() } }
      Text { id: bluetoothIcon; text: "󰂯"; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 24; color: Colors.primary }
      Text { id: titleText; text: "Pair Bluetooth device"; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 18; font.weight: Font.DemiBold; color: Colors.text; anchors.verticalCenter: parent.verticalCenter }
      Item { width: Math.max(1, parent.width - backButton.width - bluetoothIcon.implicitWidth - titleText.implicitWidth - 30); height: 1 }
    }
    Text { width: parent.width; text: "Select a nearby device to pair. PIN confirmation is handled by the Bluetooth agent."; wrapMode: Text.Wrap; color: Colors.muted; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 11 }
    Item {
      id: devicesViewport
      width: parent.width
      height: 300
      Flickable {
      id: devicesList
      anchors.fill: parent
      clip: true
      contentWidth: width
      contentHeight: devicesContent.implicitHeight
      interactive: true
      boundsBehavior: Flickable.StopAtBounds
      Column {
        id: devicesContent
        width: devicesList.width - 8
        spacing: 6
        Repeater {
          model: root.devices
          delegate: Rectangle {
            required property var modelData
            width: parent.width; height: 44; radius: 12; color: Tokens.surfaceContainerHighest
            Text { anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter; text: modelData.name || "Unknown device"; color: Colors.text; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 12 }
            Text { anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; visible: root.busyPath === (modelData.dbusPath || ""); text: "\uf013"; color: Colors.primary; font.family: "JetBrainsMono Nerd Font Propo" }
            MouseArea { anchors.fill: parent; enabled: root.radioAllowed && !root.busyPath; onClicked: root.activate(modelData) }
          }
        }
        Text { visible: root.devices.length === 0; text: root.adapter && root.adapter.discovering ? "Scanning for devices..." : "No nearby devices found"; color: Colors.muted; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 12 }
      }
      }
      Rectangle {
        visible: devicesList.contentHeight > devicesList.height
        width: 4
        radius: 2
        color: Colors.muted
        opacity: 0.6
        z: 2
        anchors.right: parent.right
        anchors.rightMargin: 1
        y: devicesList.contentY * (devicesList.height - height) / Math.max(1, devicesList.contentHeight - devicesList.height)
        height: Math.max(24, devicesList.height * devicesList.height / devicesList.contentHeight)
      }
    }
    Text { visible: root.resultText !== ""; width: parent.width; text: root.resultText; wrapMode: Text.Wrap; color: Colors.text_alt; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 11 }
  }
}
