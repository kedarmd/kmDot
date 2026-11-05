import QtQuick
import qs

// A circular arc has a stable geometric center; rotating the spinner glyph
// itself makes its uneven font bounds wobble around the circle.
Item {
  id: root
  property color color: Colors.primary
  property int size: 18
  property int duration: Tokens.busyRotation
  property bool running: true
  implicitWidth: size
  implicitHeight: size
  width: size
  height: size

  Canvas {
    id: arc
    anchors.fill: parent
    property real angle: 0
    onAngleChanged: requestPaint()
    onPaint: {
      const ctx = getContext("2d")
      ctx.reset()
      const line = Math.max(2, width * 0.12)
      ctx.lineWidth = line
      ctx.lineCap = "round"
      ctx.strokeStyle = root.color
      ctx.beginPath()
      ctx.arc(width / 2, height / 2, (Math.min(width, height) - line) / 2,
              angle * Math.PI / 180, (angle + 260) * Math.PI / 180)
      ctx.stroke()
    }
    NumberAnimation on angle {
      from: 0; to: 360; duration: root.duration
      easing.type: Easing.Linear; loops: Animation.Infinite
      running: root.running && !Tokens.reducedMotion
    }
  }
}
