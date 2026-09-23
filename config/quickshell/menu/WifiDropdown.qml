import QtQuick
import Quickshell.Io
import qs
import "../components"
import "../components/wifi.js" as WifiJs

PopupBase {
  id: root
  sockName: "kmdot-wifi-dropdown"
  title: "Wi-Fi"
  // Preserve pre-PopupBase behavior: Escape does not dismiss (base default is true).
  escapeCloses: false

  // Thin adapter over the Wifi singleton (issue #61): all nmcli radio state
  // binds here read-only; this view keeps row/section rendering, activate
  // intent, and the Dropdown-local traffic sampler only.
  readonly property var networks: Wifi.networks
  readonly property bool scanning: Wifi.scanning
  readonly property string busySsid: Wifi.busySsid
  readonly property string busyAction: Wifi.busyAction
  readonly property string errorText: Wifi.errorText
  readonly property string connectedSsid: Wifi.connectedSsid
  // Master gate: every secondary control is disabled unless the Wi-Fi radio is on.
  readonly property bool radioEnabled: Wifi.enabled

  property var pendingNetwork: null
  property string forgetSsid: ""
  // Set while a forget is deleting: the dropdown reopens once the
  // post-delete rescan lands (not immediately, which would show the stale list).
  property bool forgetPending: false
  // Live throughput sampling (see trafficProc): interface + sysfs byte counters.
  property string netIface: ""
  property double lastStamp: 0
  property real lastRx: -1
  property real lastTx: -1
  property real downMbps: 0
  property real upMbps: 0
  property bool measuring: false
  // Live-traffic feature toggle, persisted as "1"/"0" in ~/.config/kmdot/wifi-traffic.
  property bool trafficEnabled: true
  readonly property bool hasLink: root.netIface !== ""
  readonly property var connectedNetworks: root.networks.filter(n => n.active)
  readonly property var availableNetworks: root.networks.filter(n => !n.active)

  function signalGlyph(signal) { return WifiJs.signalGlyph(signal) }

  function fmtRate(mbps) {
    if (mbps >= 100) return Math.round(mbps) + " Mbps"
    if (mbps >= 10) return mbps.toFixed(1) + " Mbps"
    if (mbps >= 1) return mbps.toFixed(2) + " Mbps"
    return Math.round(mbps * 1000) + " Kbps"
  }

  function resetTrafficSample() {
    root.netIface = ""
    root.lastRx = -1
    root.lastTx = -1
    root.lastStamp = 0
    root.downMbps = 0
    root.upMbps = 0
    root.measuring = false
  }

  function sampleTraffic() {
    if (!root.trafficEnabled || !root.radioEnabled) return
    trafficProc.exec(["sh", "-c",
      "d=$(nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null | grep -m1 ':wifi:connected' | cut -d: -f1); " +
      "if [ -n \"$d\" ] && [ -r \"/sys/class/net/$d/statistics/rx_bytes\" ]; then " +
      "printf 'NET:%s %s %s\\n' \"$d\" \"$(cat /sys/class/net/$d/statistics/rx_bytes)\" \"$(cat /sys/class/net/$d/statistics/tx_bytes)\"; " +
      "else printf 'NET:none\\n'; fi"])
  }

  function setTrafficEnabled(enabled) {
    if (!root.radioEnabled) return
    root.trafficEnabled = enabled
    if (!enabled) root.resetTrafficSample()
    else root.sampleTraffic()
  }
  function refreshItems() {
    Wifi.errorText = ""
    Wifi.scan()
    root.sampleTraffic()
  }

  function editNetwork(network) {
    if (!root.radioEnabled) return
    root.close()
    if (root.scope && root.scope.wifiAddPopup) {
      root.scope.wifiAddPopup.ssid = network.ssid
      root.scope.wifiAddPopup.password = ""
      root.scope.wifiAddPopup.editingExisting = true
      root.scope.wifiAddPopup.failed = false
      root.scope.wifiAddPopup.resultText = ""
      root.scope.wifiAddPopup.anchorGX = root.anchorGX
      root.scope.wifiAddPopup.returnPopup = root
      root.scope.wifiAddPopup.open()
    }
  }
  function forgetNetwork(network) {
    if (!root.radioEnabled) return
    root.forgetSsid = network.ssid
    if (root.scope && root.scope.confirmPopup) {
      root.close()
      root.scope.confirmPopup.anchorGX = root.anchorGX
      root.scope.confirmPopup.ask("Forget Wi-Fi network", "Forget '" + network.ssid + "'? You will need to re-enter the password to connect again.")
    }
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
      if (!Wifi.enabled) {
        root.resetTrafficSample()
        root.pendingNetwork = null
      }
    }
    function onScanningChanged() {
      if (!Wifi.scanning && root.forgetPending) {
        root.forgetPending = false
        root.open()
      }
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
      required property var modelData
      readonly property bool dimmed: !!root.busySsid && root.busySsid !== modelData.ssid
      width: parent.width; height: 48; radius: 12
      opacity: root.radioEnabled ? 1 : 0.55
      color: modelData.active || root.busySsid === modelData.ssid ? Tokens.primaryContainer : Tokens.surfaceContainerHighest
      Row { anchors.fill: parent; anchors.margins: 10; spacing: 10
        Text { text: "󰤨"; color: modelData.active || root.busySsid === modelData.ssid ? Tokens.on_primary_container : Colors.text_alt; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 16; anchors.verticalCenter: parent.verticalCenter }
        Column { width: parent.width - 70; anchors.verticalCenter: parent.verticalCenter
          Text { width: parent.width; text: modelData.ssid; color: modelData.active || root.busySsid === modelData.ssid ? Tokens.on_primary_container : Colors.text; elide: Text.ElideRight; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 12 }
          Text { text: root.busySsid === modelData.ssid ? (root.busyAction === "disconnect" ? "Disconnecting..." : "Connecting...") : (modelData.active ? "Connected" : (modelData.open ? "Open" : modelData.security) + " · " + root.signalGlyph(modelData.signal) + " " + modelData.signal + "%"); color: modelData.active || root.busySsid === modelData.ssid ? Tokens.on_primary_container : Colors.muted; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 11 }
        }
        Text { id: rowSpinner; visible: root.busySsid === modelData.ssid; text: "\uf110"; color: Tokens.on_primary_container; font.family: "JetBrainsMono Nerd Font Propo"; anchors.verticalCenter: parent.verticalCenter; RotationAnimation on rotation { from: 0; to: 360; duration: 900; loops: Animation.Infinite; running: rowSpinner.visible } }
      }
      MouseArea { anchors.fill: parent; enabled: root.radioEnabled && !root.busySsid; onClicked: root.activate(modelData) }
      Row {
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        Text {
          visible: modelData.saved && !modelData.open
          text: "\uf044"
          color: modelData.active ? Tokens.on_primary_container : Colors.text_alt
          font.family: "JetBrainsMono Nerd Font Propo"
          font.pixelSize: 13
          anchors.verticalCenter: parent.verticalCenter
          MouseArea {
            anchors.fill: parent
            enabled: root.radioEnabled && !root.busySsid
            cursorShape: Qt.PointingHandCursor
            onClicked: root.editNetwork(modelData)
          }
        }
        Text {
          visible: modelData.saved && !modelData.open
          text: "\uf1f8"
          color: modelData.active ? Tokens.on_primary_container : Colors.text_alt
          font.family: "JetBrainsMono Nerd Font Propo"
          font.pixelSize: 13
          anchors.verticalCenter: parent.verticalCenter
          MouseArea {
            anchors.fill: parent
            enabled: root.radioEnabled && !root.busySsid
            cursorShape: Qt.PointingHandCursor
            onClicked: root.forgetNetwork(modelData)
          }
        }
      }
    }
  }

  Column {
    width: parent.width
    spacing: 12

    Row {
      width: parent.width; spacing: 10
      Text { id: wifiIcon; text: "󰤨"; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 24; color: Colors.primary }
      Text { id: titleText; text: "Wi-Fi"; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 18; font.weight: Font.DemiBold; color: Colors.text; anchors.verticalCenter: parent.verticalCenter }
      Item { width: Math.max(1, parent.width - wifiIcon.implicitWidth - titleText.implicitWidth - 112); height: 1 }
      PillButton { width: 30; filled: true; glyph: "\uf021"; enabled: root.radioEnabled; opacity: root.radioEnabled ? 1 : 0.5; onClicked: { Wifi.errorText = ""; Wifi.scan() } }
      Rectangle {
        width: 52; height: 28; radius: 14
        anchors.verticalCenter: parent.verticalCenter
        color: root.radioEnabled ? Tokens.primaryContainer : Tokens.surfaceContainerHighest
        opacity: 1
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
          cursorShape: Qt.PointingHandCursor
          onClicked: Wifi.toggleRadio()
        }
      }
    }

    Rectangle {
      width: parent.width
      height: 66
      radius: 14
      color: Tokens.surfaceContainerHighest
      opacity: root.trafficEnabled && root.radioEnabled ? 1 : 0.55

      Behavior on opacity { NumberAnimation { duration: 150 } }

      Row {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 14

        Column {
          width: (parent.width - 95) / 2
          spacing: 5

          Row {
            spacing: 6
            Text { text: "\uf063"; color: Colors.primary; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
            Text { text: "Download"; color: Colors.muted; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 11 }
          }

          Text {
            width: parent.width
            elide: Text.ElideRight
            text: !root.radioEnabled ? "Wi-Fi off"
              : !root.trafficEnabled ? "—"
              : !root.hasLink ? "No link"
              : root.measuring ? "Measuring…"
              : root.fmtRate(root.downMbps)
            color: root.radioEnabled && root.trafficEnabled && root.hasLink && !root.measuring ? Colors.text : Colors.muted
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 15
            font.weight: Font.DemiBold
          }
        }

        Rectangle { width: 1; height: parent.height; color: Tokens.divider }

        Column {
          width: (parent.width - 95) / 2
          spacing: 5

          Row {
            spacing: 6
            Text { text: "\uf062"; color: Colors.accent; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
            Text { text: "Upload"; color: Colors.muted; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 11 }
          }

          Text {
            width: parent.width
            elide: Text.ElideRight
            text: !root.radioEnabled ? "Wi-Fi off"
              : !root.trafficEnabled ? "—"
              : !root.hasLink ? "No link"
              : root.measuring ? "Measuring…"
              : root.fmtRate(root.upMbps)
            color: root.radioEnabled && root.trafficEnabled && root.hasLink && !root.measuring ? Colors.text : Colors.muted
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 15
            font.weight: Font.DemiBold
          }
        }

        Rectangle {
          width: 52
          height: 28
          radius: 14
          anchors.verticalCenter: parent.verticalCenter
          color: root.trafficEnabled ? Tokens.primaryContainer : Tokens.surfaceContainerHighest
          Behavior on color { ColorAnimation { duration: 150 } }

          Rectangle {
            width: 22
            height: 22
            radius: 11
            anchors.verticalCenter: parent.verticalCenter
            x: root.trafficEnabled ? parent.width - width - 3 : 3
            color: root.trafficEnabled ? Tokens.on_primary_container : Colors.muted
            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
          }

          MouseArea {
            anchors.fill: parent
            enabled: root.radioEnabled
            cursorShape: root.radioEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.setTrafficEnabled(!root.trafficEnabled)
          }
        }
      }
    }

    Item {
      id: wifiViewport
      width: parent.width
      height: 300
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
        spacing: 6
        Text { visible: !root.radioEnabled; width: parent.width; text: "Wi-Fi is turned off"; color: Colors.muted; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 12 }
        Text { text: "Connected"; color: Colors.text; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 12; font.weight: Font.DemiBold }
        Repeater { model: root.connectedNetworks; delegate: networkDelegate }
        Text { visible: !root.scanning && root.connectedNetworks.length === 0; text: "No connected network"; color: Colors.muted; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 11 }
        Text { text: "Available"; color: Colors.text; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 12; font.weight: Font.DemiBold; topPadding: 6 }
        Text { visible: root.scanning; width: parent.width; text: "Refreshing available networks..."; color: Colors.muted; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 11 }
        Repeater { model: root.availableNetworks; delegate: networkDelegate }
        Text { visible: !root.scanning && root.availableNetworks.length === 0; text: "No available networks"; color: Colors.muted; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 11 }
      }
      }
      Rectangle {
        visible: wifiList.contentHeight > wifiList.height
        width: 4
        radius: 2
        color: Colors.muted
        opacity: 0.6
        z: 2
        anchors.right: parent.right
        anchors.rightMargin: 1
        y: wifiList.contentY * (wifiList.height - height) / Math.max(1, wifiList.contentHeight - wifiList.height)
        height: Math.max(24, wifiList.height * wifiList.height / wifiList.contentHeight)
      }
    }

    Text { visible: root.errorText !== ""; width: parent.width; text: root.errorText; wrapMode: Text.Wrap; color: Colors.error; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 11 }
      PillButton {
      width: parent.width
      filled: true
      glyph: "\uf067"
      text: "Add Wi-Fi network"
      enabled: root.radioEnabled
      opacity: root.radioEnabled ? 1 : 0.5
      onClicked: if (root.scope && root.scope.wifiAddPopup) { root.close(); root.scope.wifiAddPopup.editingExisting = false; root.scope.wifiAddPopup.failed = false; root.scope.wifiAddPopup.resultText = ""; root.scope.wifiAddPopup.anchorGX = root.anchorGX; root.scope.wifiAddPopup.returnPopup = root; root.scope.wifiAddPopup.open() }
    }
  }

  Process {
    id: trafficProc
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function(data) {
        const line = String(data).trim()
        if (!line.startsWith("NET:")) return
        const parts = line.slice(4).split(" ")
        if (parts.length < 3 || parts[0] === "none") { root.resetTrafficSample(); return }
        const iface = parts[0]
        const rx = parseFloat(parts[1])
        const tx = parseFloat(parts[2])
        if (!isFinite(rx) || !isFinite(tx)) { root.resetTrafficSample(); return }
        const now = Date.now()
        // Re-baseline on interface change or counter reset (reconnect/reboot);
        // a negative lastRx marks the very first sample.
        if (root.netIface !== iface || rx < root.lastRx || tx < root.lastTx || root.lastRx < 0) {
          root.netIface = iface
          root.lastRx = rx
          root.lastTx = tx
          root.lastStamp = now
          root.measuring = true
          return
        }
        const dt = (now - root.lastStamp) / 1000
        if (dt <= 0) return
        root.downMbps = Math.max(0, (rx - root.lastRx) * 8 / dt / 1e6)
        root.upMbps = Math.max(0, (tx - root.lastTx) * 8 / dt / 1e6)
        root.lastRx = rx
        root.lastTx = tx
        root.lastStamp = now
        root.measuring = false
      }
    }
  }

  Timer {
    interval: 1000
    repeat: true
    running: root.opened && root.trafficEnabled && root.radioEnabled
    onTriggered: root.sampleTraffic()
  }

  Connections {
    target: root.scope ? root.scope.confirmPopup : null
    function onConfirmed() {
      if (!root.forgetSsid) return
      const ssid = root.forgetSsid
      root.forgetSsid = ""
      root.forgetPending = true
      Wifi.forget(ssid)
    }
    function onCancelled() {
      if (!root.forgetSsid) return
      root.forgetSsid = ""
      root.open()
    }
  }
}
