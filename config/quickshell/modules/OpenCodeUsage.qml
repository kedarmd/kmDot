import QtQuick
import qs
import "../components"

BarModule {
  id: root
  sock: "kmdot-opencode-usage"

  glyph: "\uf121"
  iconForeground: Colors.primary_alt
  tooltipText: "AI agent usage"
}
