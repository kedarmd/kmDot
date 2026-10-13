import QtQuick
import Quickshell
import Quickshell.Io
import "../components"
import qs

LauncherBase {
  id: root

  sockName: "kmdot-keybinds"
  title: "Keybinds"
  searchPlaceholder: "Search shortcuts…"
  headerTitle: "Keybinds"
  cardHeight: 584
  footerHint: "\u2191\u2193 navigate"
  deactivatable: false

  property var shortcutTargets: [
    { target: "kmdot-launcher", label: "Applications", subtitle: "Open the application launcher", glyph: "\uf00a", fallback: "Super Space" },
    { target: "kmdot-kmdot", label: "Command hub", subtitle: "Open all shell actions", glyph: "\uf120", fallback: "Super K" },
    { target: "kmdot-clipboard", label: "Clipboard", subtitle: "Browse clipboard history", glyph: "\uf0ea", fallback: "Super V" },
    { target: "kmdot-handy-launcher", label: "Handy", subtitle: "Switch models and copy transcripts", glyph: "\uf130", fallback: "Super H" },
    { target: "kmdot-system", label: "System", subtitle: "Open power actions", glyph: "\uf011", fallback: "Super Esc" }
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

  function refreshItems() {
    root.pool = root.shortcutTargets.map(function(entry) {
      return {
        target: entry.target,
        label: entry.label,
        subtitle: entry.subtitle,
        glyph: entry.glyph,
        meta: entry.fallback
      }
    })
    keybindsProc.exec(["sh", "-c",
      "lua ~/.config/kmdot/hyprland/scripts/keybinds.lua ~/.config/kmdot/hyprland/keybinds.lua"])
  }

  function addBinding(line) {
    const parts = String(line).replace(/[\r\n]+$/, "").split("\t")
    if (parts.length < 3) return
    const entry = root.shortcutTargets.find(function(target) { return target.target === parts[2] })
    if (!entry) return
    const current = root.pool.slice()
    const index = root.shortcutTargets.indexOf(entry)
    current[index] = {
      target: entry.target,
      label: entry.label,
      subtitle: entry.subtitle,
      glyph: entry.glyph,
      meta: root.formatShortcut(parts[0] || "")
    }
    root.pool = current.filter(function(item) { return !!item })
  }

  Process {
    id: keybindsProc
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function(data) {
        if (String(data).trim()) root.addBinding(data)
      }
    }
  }
}
