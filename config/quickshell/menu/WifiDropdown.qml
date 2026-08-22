import QtQuick
import Quickshell.Io
import Quickshell.Networking
import qs
import "../components"

ConnectionDropdownBase {
  id: root
  sockName: "kmdot-wifi-dropdown"
  title: "Wi-Fi"

  property var networks: []
  property string state: ""
  property bool scanning: false
  property string busySsid: ""
  property string errorText: ""
  property string connectedSsid: ""
  property string busyAction: ""
  property var savedNames: []
  property var pendingNetwork: null
  property string forgetSsid: ""
  property int _settleTries: 0
  readonly property int settleMaxTries: 8
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
  // Master gate: every secondary control is disabled unless the Wi-Fi radio is on.
  readonly property bool radioEnabled: root.state === "enabled"

  onStateChanged: {
    if (root.state !== "enabled") {
      root.resetTrafficSample()
      root.busySsid = ""
      root.busyAction = ""
      root.pendingNetwork = null
    }
  }

  function quote(s) { return "'" + s.replace(/'/g, "'\\''") + "'" }

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
  function signalGlyph(signal) {
    if (signal >= 75) return "\u2588\u2588\u2588\u2588"
    if (signal >= 50) return "\u2588\u2588\u2586\u2581"
    if (signal >= 25) return "\u2588\u2584\u2581\u2581"
    return "\u2581\u2581\u2581\u2581"
  }
  function refreshItems() {
    root.networks = []
    root.connectedSsid = ""
    root.savedNames = []
    root.scanning = true
    root.sampleTraffic()
    activeProc.exec(["sh", "-c", "nmcli -t -f NAME,TYPE connection show --active 2>/dev/null"])
    savedProc.exec(["sh", "-c", "nmcli -t -f NAME,TYPE connection show 2>/dev/null"])
    scanProc.exec(["sh", "-c", "nmcli -t -f ACTIVE,SSID,SIGNAL,SECURITY device wifi list 2>/dev/null; printf 'STATE:%s\\n' \"$(nmcli -t -f WIFI general 2>/dev/null)\""])
  }

  function beginRadioSettle() {
    root._settleTries = 0
    root.refreshItems()
    settleTimer.restart()
  }

  function addNetwork(network) {
    network.saved = root.savedNames.indexOf(network.ssid) >= 0
    network.active = network.active || network.ssid === root.connectedSsid
    for (let i = 0; i < root.networks.length; i++) {
      if (root.networks[i].ssid !== network.ssid) continue
      const updated = root.networks.slice()
      updated[i] = network
      root.networks = updated
      return
    }
    root.networks = root.networks.concat(network)
  }
  function isSaved(ssid) { return root.savedNames.indexOf(ssid) >= 0 }
  function markSaved(name) {
    for (let i = 0; i < root.networks.length; i++) {
      if (root.networks[i].ssid !== name || root.networks[i].saved) continue
      const updated = root.networks.slice()
      updated[i] = Object.assign({}, updated[i], { saved: true })
      root.networks = updated
    }
  }
  function editNetwork(network) {
    if (!root.radioEnabled) return
    root.busySsid = ""
    root.close()
    if (root.scope && root.scope.wifiAddPopup) {
      root.scope.wifiAddPopup.ssid = network.ssid
      root.scope.wifiAddPopup.password = ""
      root.scope.wifiAddPopup.editingExisting = true
      root.scope.wifiAddPopup.failed = false
      root.scope.wifiAddPopup.resultText = ""
      root.scope.wifiAddPopup.open()
    }
  }
  function forgetNetwork(network) {
    if (!root.radioEnabled) return
    root.forgetSsid = network.ssid
    if (root.scope && root.scope.confirmPopup) {
      root.busySsid = ""
      root.close()
      root.scope.confirmPopup.ask("Forget Wi-Fi network", "Forget '" + network.ssid + "'? You will need to re-enter the password to connect again.")
    }
  }
  function activate(n) {
    if (!root.radioEnabled) return
    const saved = n.saved || root.isSaved(n.ssid)
    const network = Object.assign({}, n, { saved: saved })
    root.busySsid = n.ssid
    root.busyAction = n.active ? "disconnect" : "connect"
    root.pendingNetwork = network
    root.errorText = ""
    const cmd = n.active ? "nmcli con down id " + root.quote(n.ssid)
      : (n.open ? "nmcli dev wifi connect " + root.quote(n.ssid) : "nmcli connection up id " + root.quote(n.ssid))
    if (!n.open && !n.active && !saved) {
      root.busySsid = ""
      root.close()
      if (root.scope && root.scope.wifiAddPopup) {
        root.scope.wifiAddPopup.ssid = n.ssid
        root.scope.wifiAddPopup.editingExisting = false
        root.scope.wifiAddPopup.failed = false
        root.scope.wifiAddPopup.resultText = ""
        root.scope.wifiAddPopup.open()
      }
      return
    }
    actionProc.exec(["sh", "-c", cmd + " 2>&1"])
  }

  Process {
    id: scanProc
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function(data) {
        const line = String(data)
        if (line.startsWith("STATE:")) { root.state = line.slice(6).trim(); return }
        const p = line.split(":")
        if (p.length < 4) return
        const ssid = p.slice(1, p.length - 2).join(":")
        if (!ssid) return
        const security = p[p.length - 1]
        root.addNetwork({
          ssid: ssid, active: p[0] === "yes", signal: parseInt(p[p.length - 2], 10) || 0,
          open: !security || security === "--" || security === "NONE" || security === "OPEN",
          security: security
        })
      }
    }
    onExited: {
      root.scanning = false
      root.networks.sort((a, b) => (b.active ? 1 : 0) - (a.active ? 1 : 0) || b.signal - a.signal)
    }
  }

  Process {
    id: savedProc
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function(data) {
        const p = String(data).split(":")
        if (p.length >= 2 && p[p.length - 1] === "802-11-wireless") {
          const name = p.slice(0, p.length - 1).join(":")
          if (name && root.savedNames.indexOf(name) < 0) {
            root.savedNames = root.savedNames.concat(name)
            root.markSaved(name)
          }
        }
      }
    }
  }

  Process {
    id: activeProc
    stdout: StdioCollector {
      onStreamFinished: {
        for (const line of String(this.text).split("\n")) {
          const p = line.trim().split(":")
          if (p.length < 2 || p[p.length - 1] !== "802-11-wireless") continue
          root.connectedSsid = p.slice(0, p.length - 1).join(":")
          root.addNetwork({ ssid: root.connectedSsid, active: true, signal: 0, open: false, security: "Connected" })
          return
        }
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

  Process {
    id: actionProc
    stdout: StdioCollector { onStreamFinished: root.errorText = String(this.text).trim() }
    onExited: function(code) {
      const pending = root.pendingNetwork
      if (code !== 0 && pending && !pending.active && root.scope && root.scope.wifiAddPopup) {
        root.busySsid = ""
        root.busyAction = ""
        root.pendingNetwork = null
        root.close()
        root.scope.wifiAddPopup.ssid = pending.ssid
        root.scope.wifiAddPopup.password = ""
        root.scope.wifiAddPopup.editingExisting = !!pending.saved
        root.scope.wifiAddPopup.failed = true
        root.scope.wifiAddPopup.resultText = root.errorText || "Connection failed"
        root.scope.wifiAddPopup.open()
        return
      }
      if (code !== 0) root.errorText = root.errorText || "Connection failed"
      else root.errorText = ""
      root.busySsid = ""
      root.busyAction = ""
      root.pendingNetwork = null
      root.refreshItems()
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
      PillButton { width: 30; filled: true; glyph: "\uf021"; enabled: root.radioEnabled; opacity: root.radioEnabled ? 1 : 0.5; onClicked: { root.errorText = ""; root.refreshItems() } }
      Rectangle {
        width: 52; height: 28; radius: 14
        anchors.verticalCenter: parent.verticalCenter
        color: root.state === "enabled" ? Tokens.primaryContainer : Tokens.surfaceContainerHighest
        opacity: root.state === "" ? 0.5 : 1
        Behavior on color { ColorAnimation { duration: 150 } }
        Rectangle {
          width: 22; height: 22; radius: 11
          anchors.verticalCenter: parent.verticalCenter
          x: root.state === "enabled" ? parent.width - width - 3 : 3
          color: root.state === "enabled" ? Tokens.on_primary_container : Colors.muted
          Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        }
        MouseArea {
          anchors.fill: parent
          enabled: root.state !== ""
          cursorShape: Qt.PointingHandCursor
          onClicked: radioProc.exec(["sh", "-c", "nmcli radio wifi " + (root.state === "enabled" ? "off" : "on")])
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
              : !root.trafficEnabled ? "\u2014"
              : !root.hasLink ? "No link"
              : root.measuring ? "Measuring\u2026"
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
              : !root.trafficEnabled ? "\u2014"
              : !root.hasLink ? "No link"
              : root.measuring ? "Measuring\u2026"
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
        Text { visible: root.state === "disabled"; width: parent.width; text: "Wi-Fi is turned off"; color: Colors.muted; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 12 }
        Text { visible: settleTimer.running && root.radioEnabled; width: parent.width; text: "Waiting for connection..."; color: Colors.muted; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 11 }
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
      onClicked: if (root.scope && root.scope.wifiAddPopup) { root.close(); root.scope.wifiAddPopup.editingExisting = false; root.scope.wifiAddPopup.failed = false; root.scope.wifiAddPopup.resultText = ""; root.scope.wifiAddPopup.open() }
    }
  }

  Process { id: radioProc; onExited: root.beginRadioSettle() }

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

  Timer {
    id: settleTimer
    interval: 1500
    repeat: true
    onTriggered: {
      if (!root.opened || !root.radioEnabled || root.connectedSsid !== "") {
        settleTimer.stop()
        return
      }
      root._settleTries++
      if (root._settleTries > root.settleMaxTries) {
        settleTimer.stop()
        return
      }
      root.refreshItems()
    }
  }

  Process {
    id: forgetProc
    onExited: {
      root.forgetSsid = ""
      root.errorText = ""
      root.refreshItems()
      root.open()
    }
  }

  Connections {
    target: root.scope ? root.scope.confirmPopup : null
    function onConfirmed() {
      if (!root.forgetSsid) return
      const ssid = root.forgetSsid
      root.forgetSsid = ""
      if (!root.radioEnabled) { root.open(); return }
      forgetProc.exec(["sh", "-c", "nmcli connection delete id " + root.quote(ssid)])
    }
    function onCancelled() {
      if (!root.forgetSsid) return
      root.forgetSsid = ""
      root.open()
    }
  }
}
