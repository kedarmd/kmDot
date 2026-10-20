import QtQuick
import qs

// Rounded track and fill. Drag or wheel to change; press anywhere jumps the value.
Item {
  id: root
  implicitHeight: 18

  property real value: 0
  property real wheelStep: 0.05
  property color trackColor: Tokens.surfaceContainerHighest
  property color fillColor: Tokens.primary
  property int barRadius: 5
  property real trackHeight: Math.max(4, root.height - 7)
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
