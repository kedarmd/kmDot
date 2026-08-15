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
    { label: "Keybinds", glyph: "\uf11c", action: "keybinds" },
    { label: "System", glyph: "\uf013", action: "system" },
    { label: "Themes", glyph: "\uefcc", action: "themes" }
  ]

  onActivated: function(item) {
    if (item.action === "apps") root.scope.appLauncher.openLauncher()
    else if (item.action === "system") root.scope.systemLauncher.openLauncher()
    else if (item.action === "themes") root.scope.themeLauncher.openLauncher()
    else if (item.action === "connections") root.scope.connectionsLauncher.openLauncher()
    else if (item.action === "keybinds") root.scope.keybindsLauncher.openLauncher()
    else if (item.action === "clipboard") root.scope.clipboardLauncher.openLauncher()
  }
}
