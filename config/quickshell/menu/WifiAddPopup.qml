import QtQuick
import Quickshell.Io
import qs
import "../components"

ConnectionDropdownBase {
  id: root
  title: "Add Wi-Fi connection"
  cardWidth: 360
  escapeCloses: true
  socketEnabled: false

  property string ssid: ""
  property string password: ""
  property bool editingExisting: false
  property bool busy: false
  property string resultText: ""
  property bool failed: false

  function quote(s) { return "'" + s.replace(/'/g, "'\\''") + "'" }
  function connect() {
    if (!root.ssid.trim() || root.busy) return
    root.busy = true
    root.failed = false
    root.resultText = "Connecting..."
    const command = root.editingExisting
      ? "nmcli connection modify id " + root.quote(root.ssid.trim()) + " wifi-sec.psk " + root.quote(root.password) + " && nmcli connection up id " + root.quote(root.ssid.trim())
      : "nmcli dev wifi connect " + root.quote(root.ssid.trim()) + " password " + root.quote(root.password)
    connectProc.exec(["sh", "-c", command + " 2>&1"])
  }

  function onOpenedChange() {
    if (root.opened) ssidInput.forceActiveFocus()
    else if (root.scope && root.scope.wifiDropdown) root.scope.wifiDropdown.errorText = ""
  }

  Process {
    id: connectProc
    stdout: StdioCollector { onStreamFinished: root.resultText = String(this.text).trim() }
    onExited: function(code) {
      root.busy = false
      root.failed = code !== 0
      if (!root.resultText) root.resultText = code === 0 ? "Connected" : "Connection failed"
      if (!root.opened) return
      const dropdown = root.scope ? root.scope.wifiDropdown : null
      root.close()
      if (dropdown) {
        dropdown.errorText = ""
        dropdown.open()
      }
    }
  }

  Column {
    width: parent.width; spacing: 12
    Row { width: parent.width; spacing: 10
      PillButton { id: backButton; width: 30; filled: true; glyph: "\uf060"; onClicked: { root.close(); if (root.scope && root.scope.wifiDropdown) { root.scope.wifiDropdown.errorText = ""; root.scope.wifiDropdown.open() } } }
      Text { id: wifiIcon; text: "󰤨"; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 24; color: Colors.primary }
      Text { id: titleText; text: "Add Wi-Fi connection"; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 18; font.weight: Font.DemiBold; color: Colors.text; anchors.verticalCenter: parent.verticalCenter }
      Item { width: Math.max(1, parent.width - backButton.width - wifiIcon.implicitWidth - titleText.implicitWidth - 30); height: 1 }
    }
    Text { text: "Network name (SSID)"; color: Colors.muted; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 11 }
    Rectangle { width: parent.width; height: 34; radius: 8; color: Tokens.surfaceContainerHighest
      TextInput { id: ssidInput; anchors.fill: parent; anchors.margins: 9; text: root.ssid; color: Colors.text; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 12; onTextChanged: root.ssid = text }
    }
    Text { text: "Password"; color: Colors.muted; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 11 }
    Rectangle { width: parent.width; height: 34; radius: 8; color: Tokens.surfaceContainerHighest
      TextInput { id: passwordInput; anchors.fill: parent; anchors.margins: 9; echoMode: TextInput.Password; text: root.password; color: Colors.text; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 12; onTextChanged: root.password = text; onAccepted: root.connect() }
    }
    PillButton { width: parent.width; filled: true; active: root.busy; text: root.busy ? "Connecting..." : "Connect"; enabled: true; onClicked: root.connect() }
    Text { visible: root.failed && root.resultText !== ""; width: parent.width; text: root.resultText; wrapMode: Text.Wrap; color: Colors.error; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 11 }
  }
}
