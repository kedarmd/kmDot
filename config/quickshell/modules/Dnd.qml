import QtQuick
import Quickshell.Io
import qs
import "../components"

Item {
  id: root
  implicitHeight: 32
  width: 44
  required property bool hasNotifications

  readonly property bool dndOn: DnDState.dndEnabled

  ModulePill {
    id: pill
    anchors.centerIn: parent
    width: root.width
    height: 32
    active: root.dndOn
    fill: Tokens.primaryContainer
    hovered: mouse.containsMouse
    pressed: mouse.pressed

    R1Icon {
      id: label
      anchors.centerIn: parent
      iconName: root.dndOn ? "bell-off" : "bell"
      font.family: "JetBrainsMono Nerd Font Propo"
      font.pixelSize: 20
      color: dndOn ? Tokens.on_primary_container
           : root.hasNotifications ? Colors.warning : Colors.primary_alt
    }

    Rectangle {
      opacity: root.hasNotifications && !root.dndOn ? 1 : 0
      anchors.top: parent.top
      anchors.right: parent.right
      anchors.topMargin: 2
      anchors.rightMargin: 2
      width: 6
      height: 6
      radius: 3
      color: Colors.primary

      Behavior on opacity {
        NumberAnimation { duration: Tokens.motionStandard; easing.type: Tokens.motionEasing }
      }
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton
    cursorShape: Qt.PointingHandCursor
    onClicked: notifCenterProc.exec(["sh", "-c",
      "qs ipc call notifications togglePanel 2>/dev/null || " +
      "$HOME/.config/kmdot/quickshell/scripts/toggle.sh kmdot-notifications"])
  }

  Process {
    id: notifCenterProc
  }
}
