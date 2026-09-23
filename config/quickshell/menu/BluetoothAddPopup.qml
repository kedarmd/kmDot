import QtQuick
import qs
import "../components"

PopupBase {
  id: root
  title: "Pair Bluetooth device"
  cardWidth: 360
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
      PillButton { id: backButton; width: 30; filled: true; glyph: "\uf060"; onClicked: root.goBack() }
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
            Text { anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; visible: root.busyPath === modelData.path; text: "\uf013"; color: Colors.primary; font.family: "JetBrainsMono Nerd Font Propo" }
            MouseArea { anchors.fill: parent; enabled: root.radioAllowed && !root.busyPath; onClicked: root.activate(modelData) }
          }
        }
        Text { visible: root.devices.length === 0; text: root.discovering ? "Scanning for devices..." : "No nearby devices found"; color: Colors.muted; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 12 }
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
    Text { visible: root.statusText !== ""; width: parent.width; text: root.statusText; wrapMode: Text.Wrap; color: Colors.text_alt; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 11 }
  }
}
