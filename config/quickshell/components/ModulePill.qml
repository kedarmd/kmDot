import QtQuick
import qs

// Uniform Material 3 pill for every bar module (Audio, Backlight, Battery,
// Bluetooth, Clock, Dnd, Kmdot, Network, ServerMode). Transparent when idle,
// container-fill when `active`, hover/press state layer on top. Modules wrap
// their label + MouseArea around this and drive hovered/pressed.
Rectangle {
  id: root
  implicitHeight: 30

  property bool active: false
  property color fill: Tokens.primaryContainer
  property bool disabled: false
  property bool hovered: false
  property bool pressed: false

  radius: height / 2
  color: root.disabled || !root.active ? "transparent" : root.fill

  Behavior on color {
    ColorAnimation {
      duration: 150
    }
  }

  default property alias content: contentItem.data

  Item {
    id: contentItem
    anchors.fill: parent
  }

  StateLayer {
    anchors.fill: parent
    radius: parent.radius
    hovered: root.hovered
    pressed: root.pressed
    enabled: !root.disabled
  }
}