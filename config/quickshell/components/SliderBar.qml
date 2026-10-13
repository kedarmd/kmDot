import QtQuick
import qs

// Material 3 slider: rounded track + round primary knob that grows on hover
// and press. Drag or wheel to change; press anywhere jumps the value.
Item {
  id: root
  implicitHeight: 18

  property real value: 0
  property real wheelStep: 0.05
  property color trackColor: Tokens.surfaceContainerHighest
  property color fillColor: Tokens.primary
  property int barRadius: 5
  property color thumbColor: root.fillColor
  property int thumbWidth: 18
  property int thumbHeight: 18
  property int thumbRadius: thumbWidth / 2
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

  Rectangle {
    id: knob
    x: root.displayedValue * root.width - width / 2
    y: parent.height / 2 - height / 2
    width: root.thumbWidth
    height: root.thumbHeight
    radius: root.thumbRadius
    color: root.thumbColor

    Behavior on width {
      NumberAnimation { duration: 120 }
    }
    Behavior on height {
      NumberAnimation { duration: 120 }
    }

    // Grow on hover/press, snap back when released.
    states: [
      State {
        name: "pressed"
        when: mouse.pressed
        PropertyChanges { target: knob; width: root.thumbWidth + 4; height: root.thumbHeight + 4 }
      },
      State {
        name: "hovered"
        when: mouse.containsMouse && !mouse.pressed
        PropertyChanges { target: knob; width: root.thumbWidth + 2; height: root.thumbHeight + 2 }
      }
    ]
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
