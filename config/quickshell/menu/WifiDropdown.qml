import QtQuick
import Quickshell.Io
import qs
import "../components"

PopupBase {
  id: root
  sockName: "kmdot-wifi-dropdown"
  title: "Wi-Fi"
  // Let the card follow the network count instead of leaving a large blank
  // block below the join button. The list still grows up to its viewport cap.
  cardMinHeight: !root.radioEnabled || (root.scanning && root.networks.length === 0) ? 400 : 0
  // Match the standard panel close behavior for the new R1 overlay.
  escapeCloses: true

  // Thin adapter over the Wifi singleton (issue #61): all nmcli radio state
  // binds here read-only; this view owns row/section rendering and activation.
  readonly property var networks: Wifi.networks
  readonly property bool scanning: Wifi.scanning
  readonly property string busySsid: Wifi.busySsid
  readonly property string busyAction: Wifi.busyAction
  readonly property string errorText: Wifi.errorText
  readonly property string connectedSsid: Wifi.connectedSsid
  // Master gate: every secondary control is disabled unless the Wi-Fi radio is on.
  readonly property bool radioEnabled: Wifi.enabled

  property var pendingNetwork: null
  readonly property var connectedNetworks: root.networks.filter(n => n.active)
  readonly property var availableNetworks: root.networks.filter(n => !n.active)

  function signalLabel(signal) {
    const strength = Number(signal) || 0
    if (strength >= 75) return "Excellent signal"
    if (strength >= 50) return "Good signal"
    if (strength >= 25) return "Fair signal"
    return "Weak signal"
  }

  function refreshItems() {
    Wifi.errorText = ""
    Wifi.scan()
  }

  function activate(n) {
    if (!root.radioEnabled) return
    const saved = n.saved || Wifi.isSaved(n.ssid)
    const network = Object.assign({}, n, { saved: saved })
    if (!n.open && !n.active && !saved) {
      root.close()
      if (root.scope && root.scope.wifiAddPopup) {
        root.scope.wifiAddPopup.ssid = n.ssid
        root.scope.wifiAddPopup.password = ""
        root.scope.wifiAddPopup.editingExisting = false
        root.scope.wifiAddPopup.failed = false
        root.scope.wifiAddPopup.resultText = ""
        root.scope.wifiAddPopup.anchorGX = root.anchorGX
        root.scope.wifiAddPopup.returnPopup = root
        root.scope.wifiAddPopup.open()
      }
      return
    }
    root.pendingNetwork = network
    if (n.active) Wifi.disconnect(network)
    else Wifi.connect(network)
  }

  // Failure UI stays view-shaped over the shared store errorText: a failed
  // secured connect routes to the AddPopup (failed=true + error), a failed
  // disconnect just surfaces inline via the bound errorText.
  Connections {
    target: Wifi
    function onEnabledChanged() {
      if (!Wifi.enabled) root.pendingNetwork = null
    }
    function onErrorTextChanged() {
      if (Wifi.errorText === "" || !root.pendingNetwork) return
      const pending = root.pendingNetwork
      root.pendingNetwork = null
      if (pending.active || !root.opened) return
      root.close()
      if (root.scope && root.scope.wifiAddPopup) {
        root.scope.wifiAddPopup.ssid = pending.ssid
        root.scope.wifiAddPopup.password = ""
        root.scope.wifiAddPopup.editingExisting = !!pending.saved
        root.scope.wifiAddPopup.failed = true
        root.scope.wifiAddPopup.resultText = Wifi.errorText || "Connection failed"
        root.scope.wifiAddPopup.anchorGX = root.anchorGX
        root.scope.wifiAddPopup.returnPopup = root
        root.scope.wifiAddPopup.open()
      }
    }
  }

  Component {
    id: networkDelegate
    Rectangle {
      id: networkRow
      required property var modelData
      readonly property bool dimmed: !!root.busySsid && root.busySsid !== modelData.ssid
      width: parent.width; height: 72; radius: 16
      opacity: root.radioEnabled ? 1 : 0.55
      color: modelData.active || root.busySsid === modelData.ssid ? Colors.primary_container : Colors.surface_alt
      Row { anchors.fill: parent; anchors.margins: 16; spacing: 16
        WifiIcon { width: 24; height: 24; color: modelData.active || root.busySsid === modelData.ssid ? Tokens.on_primary_container : Colors.text_alt; anchors.verticalCenter: parent.verticalCenter }
        Column { width: parent.width - 80; anchors.verticalCenter: parent.verticalCenter
          Text { width: parent.width; text: modelData.ssid; color: Colors.text; elide: Text.ElideRight; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; font.weight: Font.DemiBold }
          Text { text: root.busySsid === modelData.ssid ? (root.busyAction === "disconnect" ? "Disconnecting..." : "Connecting...") : (modelData.active ? "Connected · Secured" : (modelData.open ? "Open · " : "Saved · ") + root.signalLabel(modelData.signal)); color: Colors.text_alt; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
        }
        R1Icon { id: rowSpinner; visible: root.busySsid === modelData.ssid; glyph: "\uf110"; color: Tokens.on_primary_container; font.family: "JetBrainsMono Nerd Font Propo"; anchors.verticalCenter: parent.verticalCenter; RotationAnimation on rotation { from: 0; to: 360; duration: 900; loops: Animation.Infinite; running: rowSpinner.visible } }
      }
      MouseArea { anchors.fill: parent; enabled: root.radioEnabled && !root.busySsid; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: root.activate(modelData) }
      R1Icon { anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; visible: modelData.active; glyph: "\uf00c"; color: Colors.text; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 16 }
      R1Icon { anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; visible: !modelData.active && root.busySsid !== modelData.ssid; glyph: "\uf105"; color: Colors.text_alt; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 16 }
    }
  }

  Column {
    width: parent.width
    spacing: 12

    Row {
      width: parent.width; spacing: 10
      WifiIcon { id: wifiIcon; width: 24; height: 24; color: Colors.text; anchors.verticalCenter: parent.verticalCenter }
      Text { id: titleText; text: "Wi-Fi"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 24; font.weight: Font.DemiBold; color: Colors.text; anchors.verticalCenter: parent.verticalCenter }
      Item { width: 1; height: 1 }
    }

    Row {
      width: parent.width
      height: 56
      Column {
        width: parent.width - 64
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4
        Text { text: !root.radioEnabled ? "Wi-Fi is off" : root.scanning && root.networks.length === 0 ? "Looking for networks" : "Wi-Fi is on"; color: Colors.text; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16; font.weight: Font.DemiBold }
        Text { text: !root.radioEnabled ? "Turn on to see available networks" : root.scanning && root.networks.length === 0 ? "This can take a few seconds" : root.connectedSsid ? "Connected to " + root.connectedSsid : "Not connected"; color: Colors.text_alt; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
      }
      Rectangle {
        width: 52; height: 32; radius: 16
        anchors.verticalCenter: parent.verticalCenter
        color: root.radioEnabled ? Colors.primary : Colors.surface_alt
        Rectangle { width: 24; height: 24; radius: 12; anchors.verticalCenter: parent.verticalCenter; x: root.radioEnabled ? parent.width - width - 4 : 4; color: root.radioEnabled ? Colors.on_primary : Colors.muted; Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } } }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Wifi.toggleRadio() }
      }
    }

    Item {
      width: parent.width; height: 200; visible: !root.radioEnabled
      R1Icon { y: 40; anchors.horizontalCenter: parent.horizontalCenter; iconName: "wifi"; font.pixelSize: 24; color: Colors.text }
      Text { y: 84; width: parent.width; text: "A moment offline."; horizontalAlignment: Text.AlignHCenter; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 24; font.weight: Font.DemiBold; color: Colors.text }
      Text { y: 140; width: parent.width; text: "Saved networks will be here when you reconnect."; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: Colors.text_alt }
    }
    Column {
      width: parent.width; spacing: 16; visible: root.radioEnabled && root.scanning && root.networks.length === 0
      Repeater {
        model: 2
        Rectangle {
          width: parent.width; height: 64; radius: 16; color: Colors.surface_alt
          Rectangle { x: 64; y: 16; width: parent.width - 152; height: 8; color: Colors.border }
          Rectangle { x: 64; y: 36; width: parent.width - 224; height: 8; color: Colors.border }
        }
      }
      Text { text: "Scanning nearby networks…"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: Colors.text_alt }
    }
    Text { visible: root.radioEnabled && !(root.scanning && root.networks.length === 0); text: "YOUR NETWORKS"; color: Colors.text_alt; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.weight: Font.DemiBold }

    Item {
      id: wifiViewport
      visible: root.radioEnabled && !(root.scanning && root.networks.length === 0)
      width: parent.width
      height: Math.min(Math.max(wifiListContent.implicitHeight, 48), 232)
      Flickable {
      id: wifiList
      anchors.fill: parent
      clip: true
      contentWidth: width
      contentHeight: wifiListContent.implicitHeight
      interactive: true
      boundsBehavior: Flickable.StopAtBounds
      Column {
        id: wifiListContent
        width: wifiList.width - 8
        spacing: 8
        Text { visible: !root.radioEnabled; width: parent.width; text: "Wi-Fi is turned off"; color: Tokens.mutedText; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
        Text { visible: root.scanning; width: parent.width; text: "Refreshing available networks..."; color: Tokens.mutedText; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
        Repeater { model: root.networks; delegate: networkDelegate }
        Text { visible: !root.scanning && root.availableNetworks.length === 0; text: "No available networks"; color: Tokens.mutedText; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
      }
      }
      Rectangle {
        visible: wifiList.contentHeight > wifiList.height
        width: 4
        radius: 2
        color: Tokens.mutedText
        opacity: 0.6
        z: 2
        anchors.right: parent.right
        anchors.rightMargin: 1
        y: wifiList.contentY * (wifiList.height - height) / Math.max(1, wifiList.contentHeight - wifiList.height)
        height: Math.max(24, wifiList.height * wifiList.height / wifiList.contentHeight)
      }
    }

    Text { visible: root.errorText !== ""; width: parent.width; text: root.errorText; wrapMode: Text.Wrap; color: Tokens.errorText; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
      PillButton {
        visible: root.radioEnabled && !(root.scanning && root.networks.length === 0)
        width: parent.width
        filled: true
        active: true
        glyph: "\uf067"
        text: "Join another network"
        textSize: 14
        enabled: root.radioEnabled
        opacity: root.radioEnabled ? 1 : 0.5
        onClicked: if (root.scope && root.scope.wifiAddPopup) { root.close(); root.scope.wifiAddPopup.ssid = ""; root.scope.wifiAddPopup.password = ""; root.scope.wifiAddPopup.editingExisting = false; root.scope.wifiAddPopup.failed = false; root.scope.wifiAddPopup.resultText = ""; root.scope.wifiAddPopup.anchorGX = root.anchorGX; root.scope.wifiAddPopup.returnPopup = root; root.scope.wifiAddPopup.open() }
    }
  }

}
