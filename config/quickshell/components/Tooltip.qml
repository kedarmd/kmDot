import QtQuick
import Quickshell
import qs

PopupWindow {
  id: root
  visible: false

  readonly property int pad: 12

  FontMetrics {
    id: fm
    font.family: "JetBrainsMono Nerd Font Propo"
    font.pixelSize: 14
  }

  implicitWidth: popupWidth
  implicitHeight: popupHeight
  property int popupWidth: 100
  property int popupHeight: 20

  Rectangle {
    anchors.fill: parent
    radius: 12
    color: Colors.surface_alt
    border.color: Colors.border
    border.width: 1

    Text {
      id: label
      anchors.fill: parent
      anchors.margins: 6
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
      font.family: "JetBrainsMono Nerd Font Propo"
      font.pixelSize: 14
      color: Colors.text
    }
  }

  function show(target, text) {
    label.text = text
    popupWidth = fm.advanceWidth(text) + pad + 2
    popupHeight = fm.height + pad

    var win = target.Window.window
    if (!win) return

    anchor.window = win
    var pos = target.mapToItem(win.contentItem, target.width / 2, 0)
    var x = Math.max(4, Math.min(win.width - popupWidth - 4, pos.x - popupWidth / 2))
    anchor.rect.x = x
    anchor.rect.y = win.height + 6
    visible = true
  }

  function hide() {
    visible = false
  }
}
