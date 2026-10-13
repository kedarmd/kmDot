import QtQuick
import qs
import "../components"

PopupBase {
  id: root
  sockName: "kmdot-bluetooth-dropdown"
  title: "Bluetooth"
  cardMinHeight: 504
  escapeCloses: true

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
    return device.batteryAvailable && device.battery >= 0 ? " · Battery " + device.battery + "%" : ""
  }

  function deviceSubtitle(device) {
    if (root.busyPath === device.path) {
      if (root.busyAction === "disconnect") return "Disconnecting…"
      if (root.busyAction === "pair") return "Pairing…"
      return "Connecting…"
    }
    if (device.connected) return "Connected" + root.batterySuffix(device)
    if (device.paired) return "Paired · Not connected"
    if (device.pairing) return "Pairing…"
    return "Available to pair"
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
      width: parent.width; height: 72; radius: 16
      opacity: root.radioEnabled ? 1 : 0.55
      color: modelData.connected || busy ? Tokens.primaryContainer : Colors.surface_alt
      Row { anchors.fill: parent; anchors.margins: 16; spacing: 16
        R1Icon { glyph: modelData.icon; color: modelData.connected || busy ? Tokens.on_primary_container : Colors.text_alt; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 16; anchors.verticalCenter: parent.verticalCenter }
        Column { width: parent.width - 72; anchors.verticalCenter: parent.verticalCenter
          Text { width: parent.width; text: modelData.name; color: modelData.connected || busy ? Tokens.on_primary_container : Colors.text; elide: Text.ElideRight; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; font.weight: Font.DemiBold }
          Text { width: parent.width; text: root.deviceSubtitle(modelData); color: modelData.connected || busy ? Tokens.on_primary_container : Colors.text_alt; elide: Text.ElideRight; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
        }
        R1Icon { id: rowSpinner; visible: root.busyPath === modelData.path; glyph: "\uf110"; color: Tokens.on_primary_container; font.family: "JetBrainsMono Nerd Font Propo"; anchors.verticalCenter: parent.verticalCenter; RotationAnimation on rotation { from: 0; to: 360; duration: 900; loops: Animation.Infinite; running: rowSpinner.visible } }
      }
      MouseArea { anchors.fill: parent; enabled: root.radioEnabled && !root.busyPath; onClicked: root.activate(modelData) }
      R1Icon {
        visible: !busy
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        glyph: modelData.connected ? "\uf00c" : "\uf105"
        color: modelData.connected ? Tokens.on_primary_container : Colors.text_alt
        font.family: "JetBrainsMono Nerd Font Propo"
        font.pixelSize: 13
      }
    }
  }

  Column {
    width: parent.width; spacing: 12
    Row {
      width: parent.width; spacing: 10
      R1Icon { id: bluetoothIcon; glyph: "󰂯"; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 24; color: Colors.primary }
      Text { id: titleText; text: "Bluetooth"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 24; font.weight: Font.DemiBold; color: Colors.text; anchors.verticalCenter: parent.verticalCenter }
    }
    Row {
      width: parent.width
      height: 56
      Column {
        width: parent.width - 64
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4
        Text { text: root.radioEnabled ? "Bluetooth is on" : "Bluetooth is off"; color: Colors.text; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16; font.weight: Font.DemiBold }
        Text { text: root.radioEnabled ? "Visible while this panel is open" : "Nearby devices are unavailable"; color: Colors.text_alt; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
      }
      Rectangle {
        width: 52; height: 32; radius: 16
        anchors.verticalCenter: parent.verticalCenter
        color: root.radioEnabled ? Colors.primary : Colors.surface_alt
        opacity: root.adapter ? 1 : 0.5
        Rectangle { width: 24; height: 24; radius: 12; anchors.verticalCenter: parent.verticalCenter; x: root.radioEnabled ? parent.width - width - 4 : 4; color: root.radioEnabled ? Colors.on_primary : Colors.muted; Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } } }
        MouseArea { anchors.fill: parent; enabled: !!root.adapter; cursorShape: Qt.PointingHandCursor; onClicked: BluetoothStore.setEnabled(!root.radioEnabled) }
      }
    }

    Text { text: "YOUR DEVICES"; color: Colors.text_alt; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.weight: Font.DemiBold }

    Item {
      id: bluetoothViewport
      width: parent.width
      height: Math.min(Math.max(bluetoothListContent.implicitHeight, 48), 240)
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
        spacing: 8
        Text { visible: !root.adapter; text: "No Bluetooth adapter"; color: Colors.muted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
        Repeater { model: root.devices; delegate: deviceDelegate }
        Text { visible: root.devices.length === 0; text: root.radioEnabled && root.discovering ? "Scanning for devices..." : (root.radioEnabled ? "No devices found" : "Bluetooth is turned off"); color: Colors.muted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
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
    Text { visible: root.errorText !== ""; width: parent.width; text: root.errorText; wrapMode: Text.Wrap; color: Colors.error; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
  }

  bottomContent: PillButton {
    width: parent.width
    height: 40
    filled: true
    glyph: "\uf067"
    text: "Pair new device"
    enabled: root.radioEnabled
    opacity: root.radioEnabled ? 1 : 0.5
    onClicked: { if (root.scope && root.scope.bluetoothAddPopup) { root.close(); root.scope.bluetoothAddPopup.anchorGX = root.anchorGX; root.scope.bluetoothAddPopup.returnPopup = root; root.scope.bluetoothAddPopup.open() } }
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
