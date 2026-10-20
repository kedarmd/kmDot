import QtQuick
import qs

// Uniform Material 3 pill for every bar module (Audio, Battery,
// Bluetooth, Clock, Display, Dnd, Kmdot, Network, ServerMode). Transparent when idle,
// container-fill when `active`, hover/press state layer on top. Modules wrap
// their label + MouseArea around this and drive hovered/pressed.
Rectangle {
  id: root
  implicitHeight: 32

  property bool active: false
  property color fill: Tokens.primaryContainer
  property bool disabled: false
  property bool hovered: false
  property bool pressed: false

  radius: height / 2
  color: root.disabled ? "transparent" : root.active ? root.fill
    : root.hovered || root.pressed ? Colors.surface_alt : "transparent"

  Behavior on color {
    ColorAnimation {
      duration: Tokens.motionFast
      easing.type: Tokens.motionEasing
    }
  }

  default property alias content: contentItem.data

  Item {
    id: contentItem
    anchors.fill: parent
  }

}
