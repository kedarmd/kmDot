import QtQuick
import Quickshell.Io
import qs
import "../components"

PopupBase {
  id: root
  title: "Add Wi-Fi connection"
  cardWidth: 360
  socketEnabled: false
  focusItem: ssidInput

  property string ssid: ""
  property string password: ""
  property bool editingExisting: false
  property bool busy: false
  property string resultText: ""
  property bool failed: false
  // Injected by the opening dropdown (coordinator reopen without scope
  // strings): back/success navigation returns here instead of reading
  // scope.wifiDropdown.
  property var returnPopup: null
  // Thin adapter over the Wifi singleton (issue #61): the radio gate binds
  // the store directly; the ssid/password fields plus connect intent stay here.
  readonly property bool radioAllowed: Wifi.enabled

  function connect() {
    if (!root.radioAllowed || !root.ssid.trim() || root.busy) return
    root.busy = true
    root.failed = false
    root.resultText = "Connecting..."
    // The store declines (false) when a password is required but none was
    // given — surface it as validation instead of hanging on "Connecting...".
    if (!Wifi.connect({ ssid: root.ssid.trim(), open: false, saved: root.editingExisting }, root.password)) {
      root.busy = false
      root.failed = true
      root.resultText = "Enter a password"
    }
  }

  function openedChange() {
    if (root.opened) ssidInput.forceActiveFocus()
    else Wifi.errorText = ""
  }

  function goBack() {
    root.close()
    if (root.returnPopup) {
      Wifi.errorText = ""
      root.returnPopup.open()
    }
  }

  // Completion settles through the store (order is load-bearing: errorText
  // lands before busySsid clears, so a failure stays open with the error
  // while only the silent success path navigates back).
  Connections {
    target: Wifi
    function onEnabledChanged() {
      // Wi-Fi switched off while the password popup is open → close it.
      if (!Wifi.enabled && root.opened) root.close()
    }
    function onErrorTextChanged() {
      if (!root.busy || Wifi.errorText === "" || !root.opened) return
      if (Wifi.busySsid !== root.ssid.trim()) return
      root.busy = false
      root.failed = true
      root.resultText = Wifi.errorText
    }
    function onBusySsidChanged() {
      if (!root.busy || Wifi.busySsid !== "" || Wifi.errorText !== "" || !root.opened) return
      root.busy = false
      root.goBack()
    }
  }

  Column {
    width: parent.width; spacing: 12
    Row { width: parent.width; spacing: 10
      PillButton { id: backButton; width: 30; filled: true; glyph: "\uf060"; onClicked: root.goBack() }
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
    PillButton { width: parent.width; filled: true; active: root.busy; text: root.busy ? "Connecting..." : "Connect"; enabled: root.radioAllowed; opacity: root.radioAllowed ? 1 : 0.5; onClicked: root.connect() }
    Text { visible: root.failed && root.resultText !== ""; width: parent.width; text: root.resultText; wrapMode: Text.Wrap; color: Colors.error; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 11 }
  }
}
