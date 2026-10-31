import QtQuick
import Quickshell.Io
import qs
import "../components"

PopupBase {
  id: root
  title: "Add Wi-Fi connection"
  cardWidth: 424
  cardRadius: 20
  cardBorderWidth: 1
  cardBorderColor: Colors.outline_variant
  cardMinHeight: root.failed ? 464 : 416
  socketEnabled: false
  focusItem: root.enteringSsid ? ssidInput : passwordInput

  property string ssid: ""
  property string password: ""
  property bool enteringSsid: false
  property bool editingExisting: false
  property bool busy: false
  property string resultText: ""
  property bool failed: false
  // Injected by the opening surface: back/success navigation returns here
  // without coupling this form to a specific dropdown instance.
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
    if (root.opened) {
      root.enteringSsid = root.ssid.trim() === ""
      if (!root.enteringSsid) passwordInput.forceActiveFocus()
      else ssidInput.forceActiveFocus()
    }
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
      R1Icon { id: wifiIcon; iconName: "wifi"; font.pixelSize: 20; color: Colors.primary }
      Text { id: titleText; text: root.failed ? "Try again" : "Join a network"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 20; font.weight: Font.DemiBold; color: Colors.text; anchors.verticalCenter: parent.verticalCenter }
      Item { width: Math.max(1, parent.width - wifiIcon.implicitWidth - titleText.implicitWidth - 30); height: 1 }
    }
    Text { visible: !root.enteringSsid; text: root.ssid; color: Colors.text; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 20; font.weight: Font.DemiBold }
    Text { visible: !root.enteringSsid; width: parent.width; text: root.failed ? "The connection failed. Check your password and retry." : "Enter the password for this secured network."; wrapMode: Text.Wrap; color: Colors.text_alt; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
    Text { visible: root.enteringSsid; text: "Network name (SSID)"; color: Tokens.mutedText; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
    Rectangle { visible: root.enteringSsid; width: parent.width; height: 34; radius: 8; color: Tokens.surfaceContainerHighest
      TextInput { selectionColor: Colors.text_selection; selectedTextColor: Colors.on_text_selection; cursorDelegate: Rectangle { width: 2; height: ssidInput.cursorRectangle.height; color: Colors.cursor }
              id: ssidInput; anchors.fill: parent; anchors.margins: 9; text: root.ssid; color: Colors.text; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; onTextChanged: root.ssid = text }
    }
    Text { text: !root.enteringSsid ? "PASSWORD" : "Password"; color: Colors.text_alt; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.weight: Font.DemiBold; topPadding: !root.enteringSsid ? 24 : 0 }
    Rectangle { width: parent.width; height: !root.enteringSsid ? 42 : 34; radius: 8; color: Colors.surface_alt; border.width: root.failed ? 2 : 0; border.color: Colors.error
      TextInput { selectionColor: Colors.text_selection; selectedTextColor: Colors.on_text_selection; cursorDelegate: Rectangle { width: 2; height: passwordInput.cursorRectangle.height; color: Colors.cursor }
              id: passwordInput; anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; anchors.leftMargin: 16; anchors.rightMargin: !root.enteringSsid ? 48 : 16; height: parent.height - 12; echoMode: TextInput.Password; text: root.password; color: Colors.text; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; onTextChanged: root.password = text; onAccepted: root.connect() }
      R1Icon { visible: !root.enteringSsid; anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; glyph: "\uf023"; color: Colors.text_alt; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 16 }
    }
    Text { visible: !root.enteringSsid; text: "Your password is stored by NetworkManager."; color: Colors.text_alt; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
    Text { visible: root.failed && root.resultText !== ""; width: parent.width; text: root.resultText; wrapMode: Text.Wrap; color: Tokens.errorText; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
  }
  bottomContent: Row {
    width: parent.width; height: 34; spacing: 8
    PillButton { buttonStyle: "action"; width: (parent.width - 8) / 2; anchors.top: parent.top; anchors.bottom: parent.bottom; filled: true; text: "Cancel"; textSize: 13; enabled: !root.busy; onClicked: root.goBack() }
    PillButton { buttonStyle: "action"; width: (parent.width - 8) / 2; anchors.top: parent.top; anchors.bottom: parent.bottom; active: true; fillColor: Colors.button; activeTextColor: Colors.on_button; textSize: 13; text: root.busy ? "Connecting…" : root.failed ? "Try again" : "Connect"; enabled: root.radioAllowed && !root.busy && root.ssid.trim() !== "" && (root.editingExisting || root.password !== ""); onClicked: root.connect() }
  }
}
