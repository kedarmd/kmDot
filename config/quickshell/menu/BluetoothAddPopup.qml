import QtQuick
import qs
import "../components"

PopupBase {
  id: root
  title: "Pair Bluetooth device"
  cardWidth: 424
  cardMinHeight: 0
  cardRadius: 20
  cardBorderWidth: 1
  cardBorderColor: Colors.outline_variant
  socketEnabled: false

  // Thin adapter over the BluetoothStore singleton (issue #61): the device
  // list, busy state, and errors bind the store directly; this view keeps
  // the list rendering plus pair intent only.
  readonly property var devices: BluetoothStore.devices
  readonly property string busyPath: BluetoothStore.busyPath
  readonly property string busyAction: BluetoothStore.busyAction
  readonly property string errorText: BluetoothStore.errorText
  readonly property bool discovering: BluetoothStore.discovering
  readonly property bool radioAllowed: BluetoothStore.enabled
  readonly property var pairableDevices: root.devices.filter(d => !d.paired)
  // Injected by the opening surface: back navigation returns here without
  // coupling this form to a specific dropdown instance.
  property var returnPopup: null

  readonly property string statusText: {
    if (root.busyPath !== "") {
      const entry = root.devices.find(function(e) { return e.path === root.busyPath })
      const name = entry ? entry.name : "device"
      if (root.busyAction === "connect") return "Connecting to " + name + "..."
      return "Pairing with " + name + "..."
    }
    return root.errorText
  }

  function refreshItems() {
    BluetoothStore.refresh()
    if (root.radioAllowed) BluetoothStore.startDiscovery()
  }
  function activate(entry) {
    if (!root.radioAllowed) return
    BluetoothStore.activate(entry)
  }
  function goBack() {
    root.close()
    if (root.returnPopup) root.returnPopup.open()
  }
  function openedChange() {
    if (root.opened) {
      // Never pair into a powered-off adapter: bounce straight back out.
      if (!root.radioAllowed) { root.close(); return }
      BluetoothStore.errorText = ""
      root.refreshItems()
      return
    }
    BluetoothStore.stopDiscovery()
  }

  Connections {
    target: BluetoothStore
    function onEnabledChanged() {
      // Bluetooth switched off while the pairing popup is open → close it.
      if (!BluetoothStore.enabled && root.opened) root.close()
    }
  }

  Column {
    width: parent.width; spacing: 12
    Row { width: parent.width; spacing: 10
      R1Icon { id: bluetoothIcon; glyph: "󰂯"; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 20; color: Colors.primary }
      Text { id: titleText; text: "Pair a device"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 20; font.weight: Font.DemiBold; color: Colors.text; anchors.verticalCenter: parent.verticalCenter }
    }
    Text { width: parent.width; text: "Choose a nearby device to start pairing."; wrapMode: Text.Wrap; color: Colors.text_alt; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
    Text { text: root.discovering ? "DISCOVERING NEARBY DEVICES" : "NEARBY DEVICES"; color: Colors.text_alt; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.weight: Font.DemiBold }
    Item {
      id: devicesViewport
      width: parent.width
      height: Math.min(Math.max(devicesContent.implicitHeight, 48), 176)
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
        spacing: 8
        Repeater {
          model: root.pairableDevices
          delegate: Rectangle {
            required property var modelData
            width: parent.width; height: 72; radius: 16; color: Colors.surface_alt
            Row { anchors.fill: parent; anchors.margins: 16; spacing: 16
              R1Icon { glyph: modelData.icon; color: Colors.text_alt; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 16; anchors.verticalCenter: parent.verticalCenter }
              Column { width: parent.width - 48; anchors.verticalCenter: parent.verticalCenter
                Text { width: parent.width; text: modelData.name || "Unknown device"; color: Colors.text; elide: Text.ElideRight; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; font.weight: Font.DemiBold }
                Text { width: parent.width; text: root.busyPath === modelData.path ? root.statusText : "Ready to pair"; color: Colors.text_alt; elide: Text.ElideRight; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
              }
              R1Icon {
                visible: root.busyPath === modelData.path
                anchors.verticalCenter: parent.verticalCenter
                glyph: "\uf110"; color: Colors.text_alt
                font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 16
                RotationAnimation on rotation {
                  from: 0; to: 360; duration: Tokens.busyRotation
                  easing.type: Easing.Linear; loops: Animation.Infinite
                  running: !Tokens.reducedMotion && parent.visible
                }
              }
            }
            MouseArea { anchors.fill: parent; enabled: root.radioAllowed && !root.busyPath; onClicked: root.activate(modelData) }
          }
        }
        Text { visible: root.pairableDevices.length === 0; text: root.discovering ? "Scanning for devices…" : "No nearby devices found"; color: Tokens.mutedText; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
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
    Text { visible: root.errorText !== ""; width: parent.width; text: root.errorText; wrapMode: Text.Wrap; color: Tokens.errorText; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
    Text { width: parent.width; text: "You may be asked to confirm a PIN or passkey."; wrapMode: Text.Wrap; color: Colors.text_alt; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
  }
}
