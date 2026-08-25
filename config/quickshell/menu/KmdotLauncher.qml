import QtQuick
import Quickshell
import "../components"
import qs

LauncherBase {
  id: root

  sockName: "kmdot-kmdot"
  title: "kmDot"
  footerHint: "\u2191\u2193 navigate \u00b7 \u23ce open \u00b7 esc close"

  // NOTE: keep glyphs in the BMP (<= \uffff); non-BMP nerd glyphs (e.g. \uf0aa5) desync the QML lexer.
  items: [
    { label: "Applications", glyph: "\uf108", action: "apps" },
    { label: "Clipboard", glyph: "\uf0ea", action: "clipboard" },
    { label: "Connections", glyph: "\uf1eb", action: "connections" },
    { label: "Handy", glyph: "\uf130", action: "handy" },
    { label: "Keybinds", glyph: "\uf11c", action: "keybinds" },
    { label: "System", glyph: "\uf013", action: "system" },
    { label: "Themes", glyph: "\uefcc", action: "themes" }
  ]

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
    return nest(s.connectionsLauncher.items, "Connections")
      .concat(nest(s.systemLauncher.items, "System"))
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
