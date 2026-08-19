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

  signal changed(real v)

  function setFromX(x) {
    const v = Math.max(0, Math.min(1, x / root.width))
    root.value = v
    root.changed(v)
  }

  Rectangle {
    anchors {
      left: parent.left
      right: parent.right
      verticalCenter: parent.verticalCenter
    }
    height: Math.max(4, parent.height - 7)
    radius: root.barRadius
    color: root.trackColor
  }

  Rectangle {
    id: fill
    anchors {
      left: parent.left
      verticalCenter: parent.verticalCenter
    }
    width: root.value * root.width
    height: Math.max(4, parent.height - 7)
    radius: root.barRadius
    color: root.fillColor
  }

  Rectangle {
    id: knob
    x: root.value * root.width - width / 2
    y: parent.height / 2 - height / 2
    width: 18
    height: 18
    radius: width / 2
    color: root.fillColor

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
        PropertyChanges { width: 22; height: 22 }
      },
      State {
        name: "hovered"
        when: mouse.containsMouse && !mouse.pressed
        PropertyChanges { width: 20; height: 20 }
      }
    ]
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onPressed: root.setFromX(mouse.x)
    onPositionChanged: if (pressed) root.setFromX(mouse.x)
    onWheel: {
      const step = root.wheelStep * (wheel.angleDelta.y > 0 ? 1 : -1)
      const v = Math.max(0, Math.min(1, root.value + step))
      root.value = v
      root.changed(v)
    }
  }
}