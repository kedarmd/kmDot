import QtQuick
import Quickshell
import Quickshell.Io
import "../components"
import qs

LauncherBase {
  id: root

  sockName: "kmdot-keybinds"
  title: "Keybinds"
  footerHint: "\u2191\u2193 navigate \u00b7 esc close"
  countNoun: "keybind"
  deactivatable: false

  function refreshItems() {
    root.pool = []
    keybindsProc.exec(["sh", "-c",
      "lua ~/.config/kmdot/hyprland/scripts/keybinds.lua ~/.config/kmdot/hyprland/keybinds.lua"])
  }

  Process {
    id: keybindsProc
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function(data) {
        const line = String(data).trim()
        if (!line) return
        const parts = line.split(/\s{3,}/)
        root.pool = root.pool.concat([{
          label: parts[0] || line,
          subtitle: parts.length > 1 ? parts[1].trim() : "",
          glyph: "\uf11c"
        }])
      }
    }
  }
}
