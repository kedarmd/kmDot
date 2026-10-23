import QtQuick
import qs

// Button shape is independent of its semantic role: actions use button colors.
Rectangle {
  id: root

  property bool active: false
  property bool filled: false
  property bool keyboardSelected: false
  property bool outlined: false
  property bool emphasized: false
  property bool enabled: true
  // Action buttons follow the confirmation dialog. Use `pill` for grouped
  // selectors such as tabs, profiles, and display options.
  property string buttonStyle: "action"
  property string text: ""
  property string fontFamily: "JetBrainsMono Nerd Font"
  property string glyph: ""
  property real glyphSize: 12
  property real textSize: 14
  property color fillColor: Colors.button
  property color inactiveFillColor: Colors.surface_alt
  property color activeTextColor: Colors.on_button

  signal clicked

  activeFocusOnTab: root.enabled
  Keys.onReturnPressed: if (root.enabled) root.clicked()
  Keys.onEnterPressed: if (root.enabled) root.clicked()
  Keys.onSpacePressed: if (root.enabled) root.clicked()

  property real horizontalPadding: 12

  implicitHeight: root.buttonStyle === "pill" ? 40 : 34
  implicitWidth: row.implicitWidth + horizontalPadding * 2
  radius: root.buttonStyle === "pill" ? height / 2 : 8
  opacity: root.enabled ? 1 : 0.38
  // Hover/keyboard emphasis uses the theme focus outline, without inventing a tint.
  color: !root.enabled ? (root.outlined ? "transparent" : root.inactiveFillColor)
    : root.outlined ? (root.hovering ? Colors.surface_alt : "transparent")
    : root.active ? root.fillColor
    : root.filled ? root.inactiveFillColor
    : root.hovering ? Colors.surface_alt : "transparent"
  border.width: root.keyboardSelected || root.activeFocus || root.hovering ? 2 : root.outlined ? 1 : 0
  border.color: root.keyboardSelected || root.activeFocus || root.hovering ? Colors.focus : Colors.outline_variant

  Behavior on color {
    ColorAnimation {
      duration: Tokens.motionFast
      easing.type: Tokens.motionEasing
    }
  }

  readonly property bool hovering: mouse.containsMouse
  readonly property bool pressed: mouse.pressed
  readonly property color fg: !root.enabled
    ? Colors.text
    : root.active
      ? root.activeTextColor
    : (root.outlined || root.hovering || root.filled ? Colors.text : Tokens.on_surface_variant)

  Row {
    id: row
    anchors.centerIn: parent
    spacing: 6

    R1Icon {
      visible: root.glyph !== ""
      glyph: root.glyph
      font.family: "JetBrainsMono Nerd Font Propo"
      font.pixelSize: root.glyphSize
      font.weight: root.active ? Font.Bold : Font.Normal
      color: root.fg
    }

    Text {
      visible: root.text !== ""
      text: root.text
      font.family: root.fontFamily
      font.pixelSize: root.textSize
      font.weight: root.active || root.emphasized ? Font.DemiBold : Font.Normal
      color: root.fg
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    enabled: root.enabled
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
