import QtQuick
import Quickshell.Io
import qs
import "../components"

Item {
  id: root
  implicitHeight: 30
  width: Math.max(30, label.implicitWidth + 20)
  required property var tooltip
  required property bool hasNotifications

  readonly property bool dndOn: DnDState.dndEnabled
  readonly property string icon: dndOn ? "󰂛" : "󰂚"
  readonly property string tooltipText: dndOn
    ? "Do Not Disturb enabled"
    : "Do Not Disturb disabled"

  ModulePill {
    id: pill
    anchors.centerIn: parent
    width: Math.max(30, label.implicitWidth + 20)
    height: 30
    active: root.dndOn
    fill: root.dndOn ? Tokens.errorContainer : Tokens.warningContainer
    hovered: mouse.containsMouse
    pressed: mouse.pressed

    Text {
      id: label
      anchors.centerIn: parent
      text: icon
      font.family: "JetBrainsMono Nerd Font Propo"
      font.pixelSize: 15
      color: dndOn ? Tokens.on_error_container
           : Colors.text_alt
    }

    Rectangle {
      visible: root.hasNotifications && !root.dndOn
      anchors.top: parent.top
      anchors.right: parent.right
      anchors.topMargin: 2
      anchors.rightMargin: 2
      width: 7
      height: 7
      radius: 3.5
      color: Colors.error
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    onClicked: {
      if (mouse.button === Qt.RightButton) {
        DnDState.dndEnabled = !DnDState.dndEnabled
      } else {
        notifCenterProc.exec(["sh", "-c",
          "qs ipc call notifications togglePanel 2>/dev/null || " +
          "$HOME/.config/kmdot/quickshell/scripts/toggle.sh kmdot-notifications"])
      }
    }
    onEntered: root.tooltip.show(root, root.tooltipText)
    onExited: root.tooltip.hide()
  }

  Process {
    id: notifCenterProc
  }
}
