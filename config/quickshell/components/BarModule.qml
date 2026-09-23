import QtQuick
import Quickshell.Io
import qs

// Deepened bar-module base. Owns the pill+hover+tooltip+exec skeleton every
// top-bar module repeats: ModulePill wrap, hovered/pressed state, Left-click
// open via anchorItem + toggle.sh (self-healing, never direct open/toggle),
// optional tooltip show/hide, generic busy spinner. Subclass supplies display
// props + status sourcing only (native reactive preferred; Process poll only
// for Display brightnessctl / ServerMode script; Clock/Handy/OpenCode source
// nothing). No right-click verbs, no timers in the base.
Item {
  id: root
  implicitHeight: 30
  width: Math.max(30, label.implicitWidth + 20)

  // -- display props (subclass supplies) --
  property string glyph: "" // icon part; "" = text-only (Clock)
  property string text: "" // body part; "" = icon-only
  property bool active: false
  property color fill: Tokens.primaryContainer
  property color on_color: Tokens.on_primary_container
  property bool busy: false // spinner + rotation + primary (ServerMode today)
  property bool dimmed: false // 0.4 label opacity (disabled/off states)
  property string tooltipText: "" // "" = no tooltip (Clock)

  // -- open-path props --
  property var tooltip: null
  property string sock: "" // toggle.sh socket, e.g. "kmdot-volume"
  property bool clickable: true // false = dimmed-static no-op (no backlight)
  required property var popupRef // agnostic: anything with anchorItem

  signal wheeled(var wheel) // wheel verbs survive (Audio volume)

  property real spinAngle: 0

  NumberAnimation on spinAngle {
    from: 0
    to: 360
    duration: 1200
    running: root.busy
    loops: Animation.Infinite
  }

  readonly property string labelText: {
    if (root.busy) return ""
    if (root.glyph !== "" && root.text !== "") return root.glyph + " " + root.text
    return root.glyph + root.text
  }

  function openPopup() {
    if (!root.clickable) return
    if (root.popupRef) root.popupRef.anchorItem = root
    if (root.sock !== "") toggleProc.exec(["sh", "-c", "$HOME/.config/kmdot/quickshell/scripts/toggle.sh " + root.sock])
  }

  ModulePill {
    id: pill
    anchors.centerIn: parent
    width: Math.max(30, label.implicitWidth + 20)
    height: 30
    active: root.active
    fill: root.fill
    disabled: !root.clickable
    hovered: mouse.containsMouse
    pressed: mouse.pressed

    Text {
      id: label
      anchors.centerIn: parent
      text: root.labelText
      font.family: "JetBrainsMono Nerd Font Propo"
      font.pixelSize: 15
      color: root.busy ? Tokens.primary : (root.active ? root.on_color : Colors.text_alt)
      opacity: root.dimmed ? 0.4 : 1.0
      rotation: root.busy ? root.spinAngle : 0
      transformOrigin: Item.Center
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton
    cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: root.openPopup()
    onWheel: {
      root.wheeled(wheel)
    }
    onEntered: {
      if (root.tooltip && root.tooltipText !== "") root.tooltip.show(root, root.tooltipText)
    }
    onExited: {
      if (root.tooltip) root.tooltip.hide()
    }
  }

  Process {
    id: toggleProc
  }
}
