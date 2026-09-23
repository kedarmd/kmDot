import QtQuick
import qs
import "../components"
import "../components/bluetooth.js" as BtJs

PopupBase {
  id: root
  sockName: "kmdot-bluetooth-dropdown"
  title: "Bluetooth"
  // Preserve pre-PopupBase behavior: Escape does not dismiss (base default is true).
  escapeCloses: false

  // Thin adapter over the BluetoothStore singleton (issue #61): all BlueZ
  // radio state binds here read-only; this view keeps row/section rendering
  // plus activate/forget intent only.
  readonly property var devices: BluetoothStore.devices
  readonly property string busyPath: BluetoothStore.busyPath
  readonly property string busyAction: BluetoothStore.busyAction
  readonly property string errorText: BluetoothStore.errorText
  property string forgetPath: ""
  readonly property var connectedDevices: root.devices.filter(d => d.connected)
  readonly property var availableDevices: root.devices.filter(d => !d.connected)
  // Master gate: every secondary control is disabled unless the adapter is on.
  readonly property bool radioEnabled: BluetoothStore.enabled
  readonly property bool discovering: BluetoothStore.discovering
  readonly property var adapter: BluetoothStore.adapter

  function batterySuffix(device) {
    return BtJs.batteryLabel(device.batteryAvailable, device.battery)
  }

  function refreshItems() {
    BluetoothStore.errorText = ""
    BluetoothStore.refresh()
  }

  function activate(item) {
    if (!root.radioEnabled) return
    BluetoothStore.activate(item)
  }

  function forgetDevice(item) {
    if (!root.radioEnabled) return
    root.forgetPath = item.path
    if (root.scope && root.scope.confirmPopup) {
      root.close()
      root.scope.confirmPopup.anchorGX = root.anchorGX
      root.scope.confirmPopup.ask("Forget Bluetooth device", "Remove '" + item.name + "'" + (item.connected ? " and disconnect it" : "") + "? You will need to pair it again to use it.")
    }
  }

  function openedChange() {
    if (!root.opened) {
      BluetoothStore.stopDiscovery()
      return
    }
    BluetoothStore.errorText = ""
    BluetoothStore.refresh()
    BluetoothStore.startDiscovery()
  }

  Component {
    id: deviceDelegate
    Rectangle {
      required property var modelData
      readonly property bool busy: root.busyPath === modelData.path
      width: parent.width; height: 48; radius: 12
      opacity: root.radioEnabled ? 1 : 0.55
      color: modelData.connected || busy ? Tokens.primaryContainer : Tokens.surfaceContainerHighest
      Row { anchors.fill: parent; anchors.margins: 10; spacing: 10
        Text { text: modelData.icon; color: modelData.connected || busy ? Tokens.on_primary_container : Colors.text_alt; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 16; anchors.verticalCenter: parent.verticalCenter }
        Column { width: parent.width - 70; anchors.verticalCenter: parent.verticalCenter
          Text { width: parent.width; text: modelData.name; color: modelData.connected || busy ? Tokens.on_primary_container : Colors.text; elide: Text.ElideRight; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 12 }
          Text { text: busy ? (root.busyAction === "disconnect" ? "Disconnecting..." : root.busyAction === "pair" ? "Pairing..." : "Connecting...") : (modelData.connected ? "Connected" + root.batterySuffix(modelData) : (modelData.paired ? "Paired" + root.batterySuffix(modelData) : (modelData.pairing ? "Pairing..." : "Not paired"))); color: modelData.connected || busy ? Tokens.on_primary_container : Colors.muted; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 11 }
        }
        Text { id: rowSpinner; visible: root.busyPath === modelData.path; text: "\uf110"; color: Tokens.on_primary_container; font.family: "JetBrainsMono Nerd Font Propo"; anchors.verticalCenter: parent.verticalCenter; RotationAnimation on rotation { from: 0; to: 360; duration: 900; loops: Animation.Infinite; running: rowSpinner.visible } }
      }
      MouseArea { anchors.fill: parent; enabled: root.radioEnabled && !root.busyPath; onClicked: root.activate(modelData) }
      Text {
        visible: modelData.paired && !busy
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: "\uf1f8"
        color: modelData.connected ? Tokens.on_primary_container : Colors.text_alt
        font.family: "JetBrainsMono Nerd Font Propo"
        font.pixelSize: 13
        MouseArea {
          anchors.fill: parent
          enabled: root.radioEnabled && !root.busyPath
          cursorShape: Qt.PointingHandCursor
          onClicked: root.forgetDevice(modelData)
        }
      }
    }
  }

  Column {
    width: parent.width; spacing: 12
    Row {
      width: parent.width; spacing: 10
      Text { id: bluetoothIcon; text: "󰂯"; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 24; color: Colors.primary }
      Text { id: titleText; text: "Bluetooth"; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 18; font.weight: Font.DemiBold; color: Colors.text; anchors.verticalCenter: parent.verticalCenter }
      Item { width: Math.max(1, parent.width - bluetoothIcon.implicitWidth - titleText.implicitWidth - 112); height: 1 }
      PillButton { width: 30; filled: true; glyph: "\uf021"; enabled: root.radioEnabled; opacity: root.radioEnabled ? 1 : 0.5; onClicked: { BluetoothStore.errorText = ""; BluetoothStore.refresh() } }
      Rectangle {
        width: 52; height: 28; radius: 14
        anchors.verticalCenter: parent.verticalCenter
        color: root.radioEnabled ? Tokens.primaryContainer : Tokens.surfaceContainerHighest
        opacity: root.adapter ? 1 : 0.5
        Behavior on color { ColorAnimation { duration: 150 } }
        Rectangle {
          width: 22; height: 22; radius: 11
          anchors.verticalCenter: parent.verticalCenter
          x: root.radioEnabled ? parent.width - width - 3 : 3
          color: root.radioEnabled ? Tokens.on_primary_container : Colors.muted
          Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        }
        MouseArea {
          anchors.fill: parent
          enabled: !!root.adapter
          cursorShape: Qt.PointingHandCursor
          onClicked: BluetoothStore.setEnabled(!root.radioEnabled)
        }
      }
    }
    Item {
      id: bluetoothViewport
      width: parent.width
      height: 300
      Flickable {
      id: bluetoothList
      anchors.fill: parent
      clip: true
      contentWidth: width
      contentHeight: bluetoothListContent.implicitHeight
      interactive: true
      boundsBehavior: Flickable.StopAtBounds
      Column {
        id: bluetoothListContent
        width: bluetoothList.width - 8
        spacing: 6
        Text { visible: !root.adapter; text: "No Bluetooth adapter"; color: Colors.muted; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 12 }
        Text { text: "Connected"; color: Colors.text; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 12; font.weight: Font.DemiBold }
        Repeater { model: root.connectedDevices; delegate: deviceDelegate }
        Text { visible: root.connectedDevices.length === 0; text: "No connected devices"; color: Colors.muted; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 11 }
        Text { text: "Available"; color: Colors.text; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 12; font.weight: Font.DemiBold; topPadding: 6 }
        Repeater { model: root.availableDevices; delegate: deviceDelegate }
        Text { visible: root.devices.length === 0; text: root.radioEnabled && root.discovering ? "Scanning for devices..." : (root.radioEnabled ? "No devices found" : "Bluetooth is turned off"); color: Colors.muted; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 12 }
      }
      }
      Rectangle {
        visible: bluetoothList.contentHeight > bluetoothList.height
        width: 4
        radius: 2
        color: Colors.muted
        opacity: 0.6
        z: 2
        anchors.right: parent.right
        anchors.rightMargin: 1
        y: bluetoothList.contentY * (bluetoothList.height - height) / Math.max(1, bluetoothList.contentHeight - bluetoothList.height)
        height: Math.max(24, bluetoothList.height * bluetoothList.height / bluetoothList.contentHeight)
      }
    }
    Text { visible: root.errorText !== ""; width: parent.width; text: root.errorText; wrapMode: Text.Wrap; color: Colors.error; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 11 }
    PillButton {
      width: parent.width
      filled: true
      glyph: "\uf067"
      text: "Pair new device"
      enabled: root.radioEnabled
      opacity: root.radioEnabled ? 1 : 0.5
      onClicked: { if (root.scope && root.scope.bluetoothAddPopup) { root.close(); root.scope.bluetoothAddPopup.anchorGX = root.anchorGX; root.scope.bluetoothAddPopup.returnPopup = root; root.scope.bluetoothAddPopup.open() } }
    }
  }

  Connections {
    target: root.scope ? root.scope.confirmPopup : null
    function onConfirmed() {
      const path = root.forgetPath
      root.forgetPath = ""
      if (!root.radioEnabled) { root.open(); return }
      if (!path) { root.open(); return }
      BluetoothStore.forget(path)
      root.open()
    }
    function onCancelled() {
      if (!root.forgetPath) return
      root.forgetPath = ""
      root.open()
    }
  }
}
