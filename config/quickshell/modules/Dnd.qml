import QtQuick
import Quickshell.Io
import qs
import "../components"

Item {
  id: root
  implicitHeight: 30
  width: Math.max(30, label.implicitWidth + 20)
  required property var tooltip
  property int count: 0

  readonly property bool dndOn: DnDState.dndEnabled
  readonly property string icon: dndOn ? "󰂛" : "󰂚"
  readonly property string tooltipText: dndOn
    ? ("Do Not Disturb enabled" + (count > 0 ? " • " + count + " pending notifications" : ""))
    : "Do Not Disturb disabled"

  ModulePill {
    id: pill
    anchors.centerIn: parent
    width: Math.max(30, label.implicitWidth + 20)
    height: 30
    active: root.dndOn
    fill: root.dndOn && root.count > 0 ? Tokens.errorContainer : Tokens.warningContainer
    hovered: mouse.containsMouse
    pressed: mouse.pressed

    Text {
      id: label
      anchors.centerIn: parent
      text: count > 0 ? icon + " " + count : icon
      font.family: "JetBrainsMono Nerd Font Propo"
      font.pixelSize: 15
      color: dndOn && count > 0 ? Tokens.on_error_container
           : dndOn ? Tokens.on_warning_container
           : Colors.text_alt
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
