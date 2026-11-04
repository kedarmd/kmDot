import QtQuick
import Quickshell.Io
import qs
import "../components"

// Compact vitals beside the hidden-module chevron: CPU busy share and memory
// used share. Pure view over SystemStatsState, which owns the poll, the
// persistence, and the "hidden means nothing runs" rule.
Item {
  id: root
  implicitHeight: 32
  visible: SystemStatsState.anyEnabled
  width: root.visible ? labelRow.implicitWidth + 20 : 0

  property var popupRef: null

  Behavior on width {
    NumberAnimation { duration: Tokens.motionStandard; easing.type: Tokens.motionEasing }
  }

  function openPopup() {
    if (root.popupRef && root.popupRef.anchorItem !== undefined) root.popupRef.anchorItem = root
    toggleProc.exec(["sh", "-c", "$HOME/.config/kmdot/quickshell/scripts/toggle.sh kmdot-sysmon"])
  }

  ModulePill {
    id: pill
    anchors.centerIn: parent
    width: root.width
    height: 32
    hovered: mouse.containsMouse
    pressed: mouse.pressed
  }

  Row {
    id: labelRow
    anchors.centerIn: parent
    spacing: 10

    Row {
      visible: SystemStatsState.cpuEnabled
      anchors.verticalCenter: parent.verticalCenter
      spacing: 4

      R1Icon {
        anchors.verticalCenter: parent.verticalCenter
        iconName: "cpu"
        font.family: "JetBrainsMono Nerd Font Propo"
        font.pixelSize: 16
        color: SystemStatsState.cpuHot ? Colors.warning : Colors.primary_alt
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: SystemStatsState.cpuText
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 12
        font.weight: Font.Medium
        color: SystemStatsState.cpuHot ? Colors.warning : Colors.text_alt
      }
    }

    Row {
      visible: SystemStatsState.memEnabled
      anchors.verticalCenter: parent.verticalCenter
      spacing: 4

      R1Icon {
        anchors.verticalCenter: parent.verticalCenter
        iconName: "memory"
        font.family: "JetBrainsMono Nerd Font Propo"
        font.pixelSize: 16
        color: SystemStatsState.memHot ? Colors.warning : Colors.primary_alt
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: SystemStatsState.memText
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 12
        font.weight: Font.Medium
        color: SystemStatsState.memHot ? Colors.warning : Colors.text_alt
      }
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton
    cursorShape: Qt.PointingHandCursor
    onClicked: root.openPopup()
  }

  Process {
    id: toggleProc
  }
}
