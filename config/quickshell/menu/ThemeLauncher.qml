import QtQuick
import Quickshell
import Quickshell.Io
import "../components"
import qs

LauncherBase {
  id: root

  sockName: "kmdot-theme"
  title: "Themes"
  footerHint: "\u2191\u2193 navigate \u00b7 \u23ce switch \u00b7 esc close"

  function themeGlyph(name) {
    const map = {
      catppuccin: "\ueeed",
      everforest: "\uf1bb",
      nord: "\uf2dc",
      onedark: "\uf121",
      tokyonight: "\ueec0"
    }
    return map[name] || "\uf0c8"
  }

  function refreshItems() {
    root.pool = []
    themeListProc.exec(["sh", "-c", "$HOME/.config/kmdot/quickshell/scripts/list-themes.sh"])
  }

  function addThemeLine(line) {
    const t = line.trim()
    if (!t) return
    const parts = t.split("\t")
    const name = parts.length > 1 ? parts[1] : parts[0]
    const item = {
      label: name,
      glyph: root.themeGlyph(name),
      subtitle: parts[0] === "ACTIVE" ? "active" : ""
    }
    root.pool = root.pool.concat([item])
  }

  Process {
    id: themeListProc
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function(data) {
        root.addThemeLine(String(data))
      }
    }
  }

  onActivated: function(item) {
    root.runCommand("setsid nohup $HOME/.config/kmdot/theme-switcher/main.sh " + item.label + " >/dev/null 2>&1 < /dev/null &")
  }
}
