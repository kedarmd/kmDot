import QtQuick
import Quickshell
import Quickshell.Io
import "../components"
import qs

LauncherBase {
  id: root

  sockName: "kmdot-clipboard"
  title: "Clipboard"
  footerHint: "\u2191\u2193 navigate \u00b7 \u23ce copy \u00b7 tab clear \u00b7 esc close"
  footerActionText: "Clear"
  footerActionGlyph: "\uf2ed"
  emptyText: "Clipboard history is empty"
  loadingText: "Loading clipboard…"
  // Launchers with a footer pill hide the count (wifi/bluetooth convention) —
  // the count text would collide with the pill at the footer's right edge.
  countShown: false

  function fmtTime(epoch) {
    const now = Math.floor(Date.now() / 1000)
    const delta = Math.max(0, now - epoch)
    if (delta < 60) return "just now"
    if (delta < 3600) return Math.floor(delta / 60) + "m ago"
    if (delta < 86400) return Math.floor(delta / 3600) + "h ago"
    return Math.floor(delta / 86400) + "d ago"
  }

  function refreshItems() {
    root.loading = true
    root.pool = []
    listProc.exec(["sh", "-c", "$HOME/.config/kmdot/quickshell/scripts/clipboard-list.sh"])
  }

  function addLine(line) {
    const raw = String(line)
    if (!raw.trim()) return
    const parts = raw.split("\t")
    if (parts.length < 4) return

    const hash = parts[0]
    const type = parts[1]
    const epoch = parseInt(parts[2], 10) || 0
    const snippet = parts[3] || (type === "img" ? "Image" : "")
    const preview = parts.length > 4 ? parts[4] : ""

    root.pool = root.pool.concat([{
      hash: hash,
      label: snippet || "(empty)",
      subtitle: root.fmtTime(epoch),
      glyph: type === "img" ? "" : "\uf0ea",
      icon: type === "img" ? preview : ""
    }])
  }

  Process {
    id: listProc
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function(data) {
        root.addLine(data)
      }
    }
    onExited: root.loading = false
  }

  Process {
    id: clearProc
    onExited: root.refreshItems()
  }

  onActivated: function(item) {
    root.runCommand("$HOME/.config/kmdot/quickshell/scripts/clipboard-copy.sh " + item.hash)
  }

  onFooterActionClicked: {
    clearProc.exec(["sh", "-c", "$HOME/.config/kmdot/quickshell/scripts/clipboard-clear.sh"])
  }
}
