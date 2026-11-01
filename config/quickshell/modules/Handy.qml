import QtQuick
import qs
import "../components"

BarModule {
  id: root
  sock: "kmdot-handy"

  glyph: ""
  iconForeground: Colors.accent
  active: root.popupRef ? root.popupRef.opened : false
  tooltipText: "Selected dictation app · Super+H"
}
