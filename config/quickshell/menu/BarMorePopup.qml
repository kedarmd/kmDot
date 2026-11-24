import QtQuick
import qs
import "../components"
import "../modules"

PopupBase {
  id: root
  sockName: "kmdot-bar-more"
  cardWidth: 320
  cardRadius: 20
  cardBorderWidth: 1
  cardBorderColor: Colors.outline_variant
  focusItem: displayAction

  function showPanel(panel) {
    root.inheritAnchor(panel)
    panel.open()
  }

  // Reuse the existing status owners and actions, including mode polling.
  Item {
    visible: false
    AttentionMode { id: attention }
    ServerMode { id: server; popupRef: root.scope.serverModeDropdown }
    Bluetooth { id: bluetooth; popupRef: root.scope.bluetoothDropdown }
  }

  Text {
    text: "More controls"
    color: Colors.text
    font.family: "JetBrainsMono Nerd Font"
    font.pixelSize: 16
    font.weight: Font.DemiBold
  }
  Column {
    width: parent.width
    spacing: 6
    PillButton {
      id: displayAction
      width: parent.width
      implicitHeight: 40
      iconName: "display"
      text: "Display"
      onClicked: root.showPanel(root.scope.displayPopup)
    }
    PillButton {
      width: parent.width
      implicitHeight: 40
      iconName: bluetooth.iconName
      text: "Bluetooth · " + (bluetooth.connectedCount > 0 ? bluetooth.connectedCount + " connected" : bluetooth.btEnabled ? "On" : "Off")
      onClicked: root.showPanel(root.scope.bluetoothDropdown)
    }
    Rectangle { width: parent.width; height: 1; color: Colors.divider }
    PillButton {
      width: parent.width
      implicitHeight: 40
      iconName: attention.attentionOn ? "eye" : "eye-off"
      text: "Attention mode · " + (attention.attentionOn ? "On" : "Off")
      active: attention.attentionOn
      onClicked: attention.toggleMode()
    }
    PillButton {
      width: parent.width
      implicitHeight: 40
      glyph: "\uf233"
      text: "Server mode · " + (server.mode === "on" ? "On" : "Off")
      active: server.mode === "on"
      onClicked: root.showPanel(root.scope.serverModeDropdown)
    }
    PillButton {
      width: parent.width
      implicitHeight: 40
      glyph: "\uf121"
      text: "AI agent usage"
      onClicked: root.showPanel(root.scope.openCodeUsagePopup)
    }
  }
}
