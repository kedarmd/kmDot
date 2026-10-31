import QtQuick
import qs
import "../components"

BarModule {
  id: root
  sock: "kmdot-hex"
  glyph: ""
  iconForeground: Colors.accent
  active: root.popupRef ? root.popupRef.opened : false
  busy: HexStore.commandBusy
  tooltipText: "Hex dictation · Super+H"
}
