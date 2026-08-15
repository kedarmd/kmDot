import QtQuick
import qs

Item {
  id: root
  implicitHeight: 18

  property real value: 0
  property real wheelStep: 0.05
  property color trackColor: Colors.surface_alt
  property color fillColor: Colors.primary
  property int barRadius: 5

  signal changed(real v)

  function setFromX(x) {
    const v = Math.max(0, Math.min(1, x / root.width))
    root.value = v
    root.changed(v)
  }

  Rectangle {
    anchors.fill: parent
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
    height: parent.height
    radius: root.barRadius
    color: root.fillColor
  }

  MouseArea {
    anchors.fill: parent
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
