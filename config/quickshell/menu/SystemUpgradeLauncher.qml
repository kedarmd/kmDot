import QtQuick
import Quickshell.Io
import "../components"

LauncherBase {
  id: root

  sockName: "kmdot-system-upgrade"
  castStyle: true
  title: "Search system actions…"
  headerTitle: "System Upgrade"
  cardHeight: 520
  footerHint: "↑↓ select · ↵ open · Esc close"
  items: [
    {
      label: "Upgrade the whole system",
      subtitle: "Pacman preflight · optional recovery backup · official repositories",
      glyph: "\uf021"
    }
  ]

  readonly property string helper: decodeURIComponent(Qt.resolvedUrl("../scripts/system-upgrade.sh").toString().replace("file://", ""))

  onActivated: function(item) {
    upgradeProcess.exec([root.helper, "launch"])
  }

  Process {
    id: upgradeProcess
  }
}
