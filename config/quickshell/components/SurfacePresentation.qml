import QtQuick
import qs

// Keep a closing layer-shell surface mapped until its opacity reaches zero.
// Bind opened to logical state; reopening cancels a pending unmap.
QtObject {
  id: root
  required property bool opened
  property bool presented: false

  onOpenedChanged: {
    if (root.opened) {
      closeTimer.stop()
      root.presented = true
    } else {
      closeTimer.restart()
    }
  }

  property Timer closeTimer: Timer {
    interval: Tokens.motionStandard
    onTriggered: root.presented = false
  }
}
