import QtQuick

Canvas {
  id: root
  property color color: "white"

  onColorChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()

  onPaint: {
    const ctx = getContext("2d")
    ctx.clearRect(0, 0, width, height)
    ctx.strokeStyle = root.color
    ctx.lineWidth = 1.8 * Math.min(width, height) / 24
    ctx.lineCap = "round"

    const scale = Math.min(width, height) / 24
    const offsetX = (width - 24 * scale) / 2
    const offsetY = (height - 24 * scale) / 2
    ctx.save()
    ctx.translate(offsetX, offsetY)
    ctx.scale(scale, scale)

    ctx.beginPath()
    ctx.moveTo(2, 8)
    ctx.bezierCurveTo(7.845, 3.32, 16.155, 3.32, 22, 8)
    ctx.moveTo(5, 12)
    ctx.bezierCurveTo(9.064, 8.647, 14.936, 8.647, 19, 12)
    ctx.moveTo(8, 16)
    ctx.bezierCurveTo(10.278, 13.963, 13.722, 13.963, 16, 16)
    ctx.stroke()

    ctx.beginPath()
    ctx.arc(12, 20, 1, 0, Math.PI * 2)
    ctx.stroke()
    ctx.restore()
  }
}
