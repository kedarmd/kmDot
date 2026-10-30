import QtQuick
import "../compat" as Compat
import "../core/Brand.js" as Brand

// Same mark and color roles as kmDot's topbar: primary strokes, primary_alt dot.
Image {
  property color primary: Compat.Color.palette.primary
  property color accent: Compat.Color.palette.primary_alt || primary
  source: Brand.source(primary, accent)
  sourceSize: Qt.size(width * Screen.devicePixelRatio, height * Screen.devicePixelRatio)
  fillMode: Image.PreserveAspectFit
}
