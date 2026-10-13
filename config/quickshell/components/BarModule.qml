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
  implicitHeight: 32
  width: Math.max(36, moduleLabel.implicitWidth + 12)

  Behavior on width {
    NumberAnimation { duration: Tokens.motionStandard; easing.type: Easing.OutCubic }
  }

  // -- display props (subclass supplies) --
  property string glyph: "" // icon part; "" = text-only (Clock)
  property string iconName: ""
  property int textSize: 12
  property color foreground: Colors.text
  property string text: "" // body part; "" = icon-only
  property bool active: false
  property color fill: Tokens.primaryContainer
  property color on_color: Tokens.on_primary_container
  property bool busy: false // spinner + rotation + primary (ServerMode today)
  property bool dimmed: false // 0.4 label opacity (disabled/off states)
  property string tooltipText: "" // "" = no tooltip (Clock)

  // -- open-path props --
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

  function openPopup() {
    if (!root.clickable) return
    if (root.popupRef && root.popupRef.anchorItem !== undefined) root.popupRef.anchorItem = root
    if (root.sock !== "") toggleProc.exec(["sh", "-c", "$HOME/.config/kmdot/quickshell/scripts/toggle.sh " + root.sock])
  }

  ModulePill {
    id: pill
    anchors.centerIn: parent
    width: root.width
    height: 32
    active: root.active
    fill: root.fill
    disabled: !root.clickable
    hovered: mouse.containsMouse
    pressed: mouse.pressed

    Row {
      id: moduleLabel
      anchors.centerIn: parent
      spacing: root.glyph !== "" && root.text !== "" && !root.busy ? 5 : 0

      R1Icon {
        visible: root.busy || root.glyph !== ""
        glyph: root.busy ? "" : root.glyph
        iconName: root.busy ? "" : root.iconName
        font.family: "JetBrainsMono Nerd Font Propo"
        font.pixelSize: 24
        color: root.busy ? Tokens.primary : (root.active ? root.on_color : root.foreground)
        opacity: root.dimmed ? 0.4 : 1.0
        rotation: root.busy ? root.spinAngle : 0
        transformOrigin: Item.Center

        Behavior on color {
          ColorAnimation { duration: Tokens.motionFast }
        }
        Behavior on opacity {
          NumberAnimation { duration: Tokens.motionFast }
        }
      }

      Text {
        visible: !root.busy && root.text !== ""
        text: root.text
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: root.textSize
        font.weight: Font.Medium
        color: root.active ? root.on_color : root.foreground
        opacity: root.dimmed ? 0.4 : 1.0

        Behavior on color {
          ColorAnimation { duration: Tokens.motionFast }
        }
        Behavior on opacity {
          NumberAnimation { duration: Tokens.motionFast }
        }
      }
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
  }

  Process {
    id: toggleProc
  }
}
