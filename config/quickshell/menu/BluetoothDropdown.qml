import QtQuick
import Quickshell.Bluetooth
import qs
import "../components"

ConnectionDropdownBase {
  id: root
  sockName: "kmdot-bluetooth-dropdown"
  title: "Bluetooth"

  property var devices: []
  property string busyPath: ""
  property string busyAction: ""
  property string errorText: ""
  property string forgetPath: ""
  readonly property var connectedDevices: root.devices.filter(d => d.connected)
  readonly property var availableDevices: root.devices.filter(d => !d.connected)
  // Master gate: every secondary control is disabled unless the adapter is on.
  readonly property bool radioEnabled: !!root.adapter && root.adapter.enabled

  function deviceGlyph(icon) {
    switch (String(icon || "").toLowerCase()) {
      case "input-keyboard": return "\uf11c"
      case "input-mouse": return "\uf245"
      case "audio-headset":
      case "audio-headphones": return "\uf025"
      case "phone":
      case "smartphone": return "\uf10b"
      case "computer":
      case "laptop": return "\uf109"
      case "video-display": return "\uf26c"
      default: return "\uf293"
    }
  }

  function refreshItems() {
    let out = []
    if (Bluetooth.devices) {
      for (const d of Bluetooth.devices.values) {
        if (!d.name) continue
        const path = d.dbusPath || ""
        const connected = !!d.connected
        const paired = !!d.paired
        out.push({ device: d, path: path, name: String(d.name), connected: connected, paired: paired, pairing: !!d.pairing, icon: deviceGlyph(d.icon) })
        wire(d)
        if (path === root.busyPath) {
          if (root.busyAction === "pair" && paired) {
            try { d.connect(); root.busyAction = "connect" } catch (e) { root.errorText = String(e); root.busyPath = ""; root.busyAction = "" }
          } else if (root.busyAction === "connect" && connected) {
            root.busyPath = ""; root.busyAction = ""; busyTimer.stop()
          } else if (root.busyAction === "disconnect" && !connected) {
            root.busyPath = ""; root.busyAction = ""; busyTimer.stop()
          } else if (root.busyAction === "pair" && !d.pairing && !paired) {
            root.errorText = "Pairing failed"
            root.busyPath = ""; root.busyAction = ""; busyTimer.stop()
          }
        }
      }
    }
    out.sort((a, b) => (b.connected ? 1 : 0) - (a.connected ? 1 : 0) || (b.paired ? 1 : 0) - (a.paired ? 1 : 0) || a.name.localeCompare(b.name))
    root.devices = out
  }

  property var wired: []
  function wire(d) {
    if (root.wired.indexOf(d) >= 0) return
    d.connectedChanged.connect(root.refreshItems)
    d.pairedChanged.connect(root.refreshItems)
    d.pairingChanged.connect(root.refreshItems)
    d.nameChanged.connect(root.refreshItems)
    root.wired = root.wired.concat(d)
  }

  function activate(item) {
    if (!root.radioEnabled) return
    root.busyPath = item.path
    root.busyAction = item.connected ? "disconnect" : (item.paired ? "connect" : "pair")
    root.errorText = ""
    try {
      if (item.connected) item.device.disconnect()
      else if (item.paired) item.device.connect()
      else item.device.pair()
    } catch (e) {
      root.errorText = String(e)
      root.busyPath = ""
      root.busyAction = ""
      busyTimer.stop()
    }
    if (root.busyPath) busyTimer.restart()
  }

  function forgetDevice(item) {
    if (!root.radioEnabled) return
    root.forgetPath = item.path
    if (root.scope && root.scope.confirmPopup) {
      root.busyPath = ""
      root.busyAction = ""
      busyTimer.stop()
      root.close()
      root.scope.confirmPopup.ask("Forget Bluetooth device", "Remove '" + item.name + "'" + (item.connected ? " and disconnect it" : "") + "? You will need to pair it again to use it.")
    }
  }

  function openedChange() {
    if (!root.opened) {
      if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.discovering = false
      return
    }
    root.errorText = ""
    root.refreshItems()
    if (Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled) Bluetooth.defaultAdapter.discovering = true
  }

  Connections { target: Bluetooth; function onDefaultAdapterChanged() { root.refreshItems() } }
  Connections {
    target: root.adapter
    function onEnabledChanged() {
      // Adapter switched off: stop discovery and drop any in-flight operation.
      if (root.adapter && !root.adapter.enabled) {
        if (root.adapter.discovering) root.adapter.discovering = false
        busyTimer.stop()
        root.busyPath = ""
        root.busyAction = ""
        root.errorText = ""
      }
      root.refreshItems()
    }
    function onDiscoveringChanged() { root.refreshItems() }
  }
  readonly property var adapter: Bluetooth.defaultAdapter

  Timer {
    id: busyTimer
    interval: 15000
    repeat: false
    onTriggered: {
      if (!root.busyPath) return
      root.errorText = "Bluetooth operation timed out"
      root.busyPath = ""
      root.busyAction = ""
    }
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
          Text { text: busy ? (root.busyAction === "disconnect" ? "Disconnecting..." : root.busyAction === "pair" ? "Pairing..." : "Connecting...") : (modelData.connected ? "Connected" : (modelData.paired ? "Paired" : (modelData.pairing ? "Pairing..." : "Not paired"))); color: modelData.connected || busy ? Tokens.on_primary_container : Colors.muted; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 11 }
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
      PillButton { width: 30; filled: true; glyph: "\uf021"; enabled: root.radioEnabled; opacity: root.radioEnabled ? 1 : 0.5; onClicked: { root.errorText = ""; root.refreshItems() } }
      Rectangle {
        width: 52; height: 28; radius: 14
        anchors.verticalCenter: parent.verticalCenter
        color: root.adapter && root.adapter.enabled ? Tokens.primaryContainer : Tokens.surfaceContainerHighest
        opacity: root.adapter ? 1 : 0.5
        Behavior on color { ColorAnimation { duration: 150 } }
        Rectangle {
          width: 22; height: 22; radius: 11
          anchors.verticalCenter: parent.verticalCenter
          x: root.adapter && root.adapter.enabled ? parent.width - width - 3 : 3
          color: root.adapter && root.adapter.enabled ? Tokens.on_primary_container : Colors.muted
          Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        }
        MouseArea {
          anchors.fill: parent
          enabled: !!root.adapter
          cursorShape: Qt.PointingHandCursor
          onClicked: if (root.adapter) root.adapter.enabled = !root.adapter.enabled
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
        Text { visible: root.devices.length === 0; text: root.adapter && root.adapter.enabled && root.adapter.discovering ? "Scanning for devices..." : (root.adapter && root.adapter.enabled ? "No devices found" : "Bluetooth is turned off"); color: Colors.muted; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 12 }
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
      onClicked: { if (root.scope && root.scope.bluetoothAddPopup) { root.close(); root.scope.bluetoothAddPopup.open() } }
    }
  }

  Connections {
    target: root.scope ? root.scope.confirmPopup : null
    function onConfirmed() {
      const path = root.forgetPath
      root.forgetPath = ""
      if (!root.radioEnabled) { root.open(); return }
      const item = root.devices.find(d => d.path === path)
      if (!item || (!item.paired && !item.connected)) return
      try {
        if (item.connected) item.device.disconnect()
        item.device.forget()
        busyTimer.stop()
        root.busyPath = ""
        root.busyAction = ""
        root.errorText = ""
      } catch (e) { root.errorText = String(e) }
      root.refreshItems()
      root.open()
    }
    function onCancelled() {
      if (!root.forgetPath) return
      root.forgetPath = ""
      root.open()
    }
  }
}
