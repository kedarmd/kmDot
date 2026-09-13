import QtQuick
import Quickshell.Io
import qs
import "../components"

// Thin view over the DisplayState singleton (issue #49): icon + tooltip +
// click-to-open + wheel-to-adjust. No detection, no pollers, no brightness
// Processes of its own (toggleProc only fires the popup socket).
Item {
  id: root
  implicitHeight: 30
  width: Math.max(30, label.implicitWidth + 20)
  required property var tooltip
  property var popup

  readonly property bool hasBacklight: DisplayState.barHasBacklight
  readonly property int percent: DisplayState.barPercent
  readonly property string icon: ""
  readonly property string text: icon

  readonly property string tooltipText: {
    if (!hasBacklight) return "Display (no backlight)"
    return "Brightness: " + percent + "%"
  }

  ModulePill {
    id: pill
    anchors.centerIn: parent
    width: Math.max(30, label.implicitWidth + 20)
    height: 30
    hovered: mouse.containsMouse
    pressed: mouse.pressed

    Text {
      id: label
      anchors.centerIn: parent
      text: root.text
      font.family: "JetBrainsMono Nerd Font Propo"
      font.pixelSize: 15
      color: Colors.text_alt
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: {
      if (root.popup) root.popup.anchorItem = root
      toggleProc.exec(["sh", "-c", "$HOME/.config/kmdot/quickshell/scripts/toggle.sh kmdot-display"])
    }
    onWheel: {
      if (root.hasBacklight) DisplayState.nudgeBar(wheel.angleDelta.y > 0 ? 1 : -1)
    }
    onEntered: root.tooltip.show(root, root.tooltipText)
    onExited: root.tooltip.hide()
  }

  Process {
    id: toggleProc
  }
}
