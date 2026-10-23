import QtQuick
import Quickshell
import Quickshell.Io
import "../components"
import qs

LauncherBase {
  id: root

  sockName: "kmdot-keybinds"
  castStyle: true
  metaAsKeys: true
  title: "Keybinds"
  searchPlaceholder: "Search shortcuts…"
  headerTitle: "Keybinds"
  cardHeight: 520
  footerHint: "↑↓ navigate"
  deactivatable: false
  countShown: true
  countNoun: "shortcut"
  property bool snapshotLoaded: false
  loadingText: "Reading active keybindings…"
  emptyText: root.pool.length > 0 ? "No matching shortcuts" : "No active keybindings"

  readonly property string collectorPath: decodeURIComponent(Qt.resolvedUrl("../scripts/keybinds.mjs").toString().replace(/^file:\/\//, ""))

  function refreshItems() {
    if (snapshotProc.running) return
    root.loading = !root.snapshotLoaded
    snapshotProc.exec(["node", root.collectorPath])
  }

  function applySnapshot(text) {
    root.snapshotLoaded = true
    try {
      const data = JSON.parse(text)
      if (!data.ok || !Array.isArray(data.items)) throw new Error(data.error || "Unable to read active keybindings")
      root.listErrorText = ""
      if (JSON.stringify(root.pool) !== JSON.stringify(data.items)) {
        const selectedId = root.selectedItem ? root.selectedItem.id : ""
        root.pool = data.items
        const index = root.results.findIndex(row => row.item.id === selectedId)
        if (index >= 0) root.selectedIndex = index
      }
    } catch (error) {
      root.pool = []
      root.listErrorText = String(error.message || error)
    }
  }

  function matchScore(item, query) {
    const normalise = value => String(value || "").replace(/\+/g, " ").replace(/\s+/g, " ").trim()
    const keyScore = value => {
      const keys = normalise(value).toLowerCase()
      const wanted = normalise(query).toLowerCase()
      if (query.indexOf("+") >= 0) return keys === wanted ? 100000 : keys.indexOf(wanted) >= 0 ? 50000 : -1
      return root.fieldScore(keys, wanted)
    }
    return Math.max(root.fieldScore(item.label, query), root.fieldScore(item.subtitle, query),
      keyScore(item.meta), keyScore(item.rawKeys))
  }

  Timer {
    interval: 2000
    repeat: true
    running: root.opened
    onTriggered: root.refreshItems()
  }

  Process {
    id: snapshotProc
    stdout: StdioCollector { onStreamFinished: root.applySnapshot(text) }
    onExited: function(exitCode) {
      root.loading = false
      if (exitCode !== 0) {
        root.pool = []
        root.listErrorText = "Unable to read active keybindings"
      }
    }
  }
}
