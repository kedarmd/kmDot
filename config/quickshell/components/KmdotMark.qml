import QtQuick
import qs
import "../launcher/plugin/core/Brand.js" as Brand

// The kmDot logo is brand artwork rather than a symbolic UI icon.
Image {
  property color primary: Colors.text
  property color accent: Colors.primary

  source: Brand.source(primary, accent)
  sourceSize: Qt.size(width * Screen.devicePixelRatio, height * Screen.devicePixelRatio)
  fillMode: Image.PreserveAspectFit
}
