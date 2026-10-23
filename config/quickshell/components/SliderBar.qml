import QtQuick
import qs

// Rounded track and fill. Drag or wheel to change; press anywhere jumps the value.
Item {
  id: root
  implicitHeight: 18

  property real value: 0
  property real wheelStep: 0.05
  property color trackColor: Colors.slider_track
  property color fillColor: Colors.control
  property int barRadius: 5
  property real trackHeight: Math.max(4, root.height - 7)
  // Audio rows opt into the launcher-style slider: a slim track and a clear
  // thumb. Other controls keep their existing flat bar by default.
  property bool thumbVisible: false
  property real thumbSize: 16
  property color thumbColor: Colors.surface_high
  property color thumbBorderColor: Colors.primary
  property real dragValue: root.value
  readonly property real displayedValue: mouse.pressed ? root.dragValue : root.value

  signal changed(real v)

  function setFromX(x) {
    const v = Math.max(0, Math.min(1, x / root.width))
    // The caller owns value. Assigning to it here would break its binding to
    // PipeWire/DisplayState, leaving the thumb stale after external changes.
    root.dragValue = v
    root.changed(v)
  }

  Rectangle {
    anchors {
      left: parent.left
      right: parent.right
      verticalCenter: parent.verticalCenter
    }
    height: root.trackHeight
    radius: root.barRadius
    color: root.trackColor
  }

  Rectangle {
    id: fill
    anchors {
      left: parent.left
      verticalCenter: parent.verticalCenter
    }
    width: root.displayedValue * root.width
    height: root.trackHeight
    radius: root.barRadius
    color: root.fillColor
  }

  Rectangle {
    id: thumb
    visible: root.thumbVisible
    width: root.thumbSize
    height: width
    x: root.displayedValue * root.width - width / 2
    anchors.verticalCenter: parent.verticalCenter
    radius: width / 2
    color: root.thumbColor
    border.width: 2
    border.color: root.thumbBorderColor
    scale: mouse.pressed ? 1.12 : mouse.containsMouse ? 1.06 : 1
    Behavior on scale { NumberAnimation { duration: Tokens.motionFast; easing.type: Tokens.motionEasing } }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onPressed: event => root.setFromX(event.x)
    onPositionChanged: event => { if (pressed) root.setFromX(event.x) }
    onWheel: wheel => {
      const step = root.wheelStep * (wheel.angleDelta.y > 0 ? 1 : -1)
      const v = Math.max(0, Math.min(1, root.value + step))
      root.changed(v)
    }
  }
}
