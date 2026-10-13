import QtQuick
import Quickshell
import Quickshell.Io
import "../components"
import qs

LauncherBase {
  id: root

  sockName: "kmdot-kmdot"
  title: "Search apps, settings, and actions…"
  headerTitle: root.query.trim() === "" ? "Kmdot" : "Search"
  cardHeight: root.query.trim() === "" ? 728 : 472
  listTopMargin: 24
  footerHint: "\u2191\u2193 navigate \u00b7 \u23ce open"

  property var shortcutMap: ({})
  property var _shortcutOutput: ({})

  // NOTE: keep glyphs in the BMP (<= \uffff); non-BMP nerd glyphs (e.g. \uf0aa5) desync the QML lexer.
  items: [
    { label: "Applications", subtitle: "Open an app", shortcutTarget: "kmdot-launcher", glyph: "\uf00a", action: "apps" },
    { label: "Clipboard", subtitle: "Recent text and images", shortcutTarget: "kmdot-clipboard", glyph: "\uf0ea", action: "clipboard" },
    { label: "Connections", subtitle: "Wi-Fi and Bluetooth", shortcutTarget: "kmdot-connections", glyph: "\uf1eb", action: "connections" },
    { label: "Handy", subtitle: "Models and transcriptions", shortcutTarget: "kmdot-handy-launcher", glyph: "\uf130", action: "handy" },
    { label: "Keybinds", subtitle: "Your keyboard shortcuts", shortcutTarget: "kmdot-keybinds", glyph: "\uf11c", action: "keybinds" },
    { label: "System", subtitle: "Lock, suspend, and power", shortcutTarget: "kmdot-system", glyph: "\uf013", action: "system" },
    { label: "Appearance", subtitle: "Change color theme", shortcutTarget: "kmdot-theme", glyph: "\uf1fc", action: "themes" }
  ]

  function formatShortcut(key) {
    return String(key).split(/\s*\+\s*/).map(function(part) {
      const upper = part.toUpperCase()
      if (upper === "SUPER") return "Super"
      if (upper === "SHIFT") return "Shift"
      if (upper === "CTRL" || upper === "CONTROL") return "Ctrl"
      if (upper === "ALT") return "Alt"
      if (upper === "ESCAPE" || upper === "ESC") return "Esc"
      if (upper === "RETURN") return "Enter"
      if (upper === "SPACE") return "Space"
      return part.length === 1 ? upper : part
    }).join(" ")
  }

  function withShortcut(item) {
    const key = item.shortcutTarget ? root.shortcutMap[item.shortcutTarget] : ""
    return Object.assign({}, item, { meta: key ? root.formatShortcut(key) : "" })
  }

  function refreshItems() {
    root.pool = root.items.map(item => root.withShortcut(item))
    root._shortcutOutput = ({})
    keybindsProc.exec(["sh", "-c",
      "lua ~/.config/kmdot/hyprland/scripts/keybinds.lua ~/.config/kmdot/hyprland/keybinds.lua"])
  }

  // Nested search: children of Connections/System ride the query as clones
  // tagged with their section (rendered as the row subtitle). Sources are the
  // owning launchers' own item lists — no duplication here. The `nested` tag
  // lives on the clone only, so the real launchers' own rows never change.
  function nest(items, section) {
    const out = []
    for (const it of items) out.push(Object.assign({}, it, { subtitle: section, nested: true }))
    return out
  }

  function nestedItems() {
    if (!root.scope) return []
    const s = root.scope
    return nest(s.connectionsLauncher.items.map(item => root.withShortcut(item)), "Connections")
      .concat(nest(s.systemLauncher.items.map(item => root.withShortcut(item)), "System"))
  }

  // Breadcrumb display for nested results only ("Connections → Wi-Fi"); plain
  // labels everywhere else (incl. Connections/System opened directly).
  function itemTitle(item) {
    if (!item.nested) return root.itemLabel(item)
    return item.subtitle + " \u2192 " + root.itemLabel(item)
  }

  // The breadcrumb replaces the second line — hide it on nested rows.
  function itemSubtitleLive(item) {
    return item.nested ? "" : root.itemSubtitle(item)
  }

  // Empty query shows only the top-level menu; a typed query merges the nested
  // children in. matchScore() scores label AND subtitle (= section name), so
  // "wifi" and even "connections" both hit; +500 keeps top-level entries ranked
  // above same-scoring nested ones.
  function filterAndSort(items, q) {
    const out = []
    if (!q) {
      for (const it of items) out.push({ item: it, score: 0 })
      return out
    }
    const p = q.toLowerCase()
    for (const it of items) {
      const s = root.matchScore(it, p)
      if (s >= 0) out.push({ item: it, score: s + 500 })
    }
    for (const it of root.nestedItems()) {
      const s = root.matchScore(it, p)
      if (s >= 0) out.push({ item: it, score: s })
    }
    out.sort((a, b) => b.score - a.score)
    return out
  }

  Process {
    id: keybindsProc
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function(data) {
        const line = String(data).replace(/[\r\n]+$/, "")
        if (!line.trim()) return
        const fields = line.split("\t")
        if (fields.length >= 3 && fields[0] && fields[2])
          root._shortcutOutput[fields[2]] = fields[0]
      }
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) root._shortcutOutput = ({})
      root.shortcutMap = Object.assign({}, root._shortcutOutput)
      root.pool = root.items.map(item => root.withShortcut(item))
    }
  }

  onActivated: function(item) {
    // Nested System clones carry command → run directly (deep-link).
    if (item.command) {
      root.runCommand(item.command)
      return
    }
    if (item.action === "apps") root.scope.appLauncher.openLauncher()
    else if (item.action === "system") root.scope.systemLauncher.openLauncher()
    else if (item.action === "themes") root.scope.themeLauncher.openLauncher()
    else if (item.action === "connections") root.scope.connectionsLauncher.openLauncher()
    else if (item.action === "keybinds") root.scope.keybindsLauncher.openLauncher()
    else if (item.action === "clipboard") root.scope.clipboardLauncher.openLauncher()
    else if (item.action === "handy") root.scope.handyLauncher.openLauncher()
    // Nested Connections deep-links open their real launchers directly.
    else if (item.action === "bluetooth") root.scope.bluetoothLauncher.openLauncher()
    else if (item.action === "wifi") root.scope.wifiLauncher.openLauncher()
  }
}
