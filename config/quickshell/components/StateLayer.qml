import QtQuick
import qs

// Material 3 state layer: an animated hover/pressed overlay. Drop it inside a
// clickable surface (anchors.fill), feed hovered/pressed from the owning
// MouseArea, and it renders the on-surface state tint. Keeps every interactive
// element (workspaces, modules, rows, pills, calendar cells) behaving alike.
Rectangle {
  id: root

  property bool hovered: false
  property bool pressed: false
  property bool enabled: true

  color: root.enabled && root.pressed
    ? Tokens.statePressed
    : root.enabled && root.hovered
      ? Tokens.stateHover
      : "transparent"

  Behavior on color {
    ColorAnimation {
      duration: 120
    }
  }
}