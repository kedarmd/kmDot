import QtQuick
import Quickshell
import Quickshell.Io
import "../components"
import qs

LauncherBase {
  id: root

  sockName: "kmdot-theme"
  title: "Appearance"
  headerTitle: "Appearance"
  cardHeight: 760
  themePreview: true
  themePreviewPalette: root.selectedItem ? root.selectedItem.palette : null
  searchEnabled: false
  footerHint: "\u2191\u2193 preview \u00b7 \u23ce apply"

  property var _themeRows: []

  function themeLabel(name) {
    if (name === "tokyonight") return "TokyoNight · Night"
    if (name === "catppuccin") return "Catppuccin · Mocha"
    if (name === "everforest") return "Everforest · Dark"
    if (name === "onedark") return "One Dark"
    return name.charAt(0).toUpperCase() + name.slice(1)
  }

  function themeGlyph(name) {
    if (name === "tokyonight") return "\uf186" // moon
    if (name === "catppuccin") return "\uf00a" // grid
    if (name === "everforest") return "\uf0ac" // globe
    if (name === "nord") return "\uf011" // power
    if (name === "onedark") return "\uf120" // terminal
    return "\uf1fc" // paint brush for an unrecognized future theme
  }

  function readThemeRow(line) {
    const row = JSON.parse(String(line))
    const palette = row.palette
    const active = row.active
    const theme = row.theme
    root._themeRows.push({
      label: root.themeLabel(theme),
      theme: theme,
      glyph: root.themeGlyph(theme),
      subtitle: active ? "The current color palette" : "Preview · Enter to apply",
      meta: active ? "Active" : "",
      swatches: [],
      active: active,
      palette: palette
    })
  }

  function refreshItems() {
    root._themeRows = []
    themeListProc.exec(["sh", "-c", "$HOME/.config/kmdot/quickshell/scripts/list-themes.sh"])
  }

  onActivated: function(item) {
    // Keep the switch detached: the quickshell hook restarts its parent. Preserve
    // failures in a log and notify after the switcher exits so a hook error is
    // visible instead of looking like the selection did nothing.
    root.runCommand("setsid nohup sh -c '\"$HOME/.config/kmdot/theme-switcher/main.sh\" \"$1\" > \"$HOME/.cache/kmdot-theme-switcher.log\" 2>&1; status=$?; if [ $status -ne 0 ]; then notify-send \"Theme switch failed\" \"$(tail -n 3 \"$HOME/.cache/kmdot-theme-switcher.log\")\"; fi' sh " + item.theme + " </dev/null >/dev/null 2>&1 &")
  }

  Process {
    id: themeListProc
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function(data) {
        const line = String(data).replace(/[\r\n]+$/, "")
        if (line !== "") root.readThemeRow(line)
      }
    }
    onExited: {
      root._themeRows.sort((a, b) => Number(b.active) - Number(a.active)
        || a.label.localeCompare(b.label))
      root.pool = root._themeRows
      const activeIndex = root.pool.findIndex(item => item.active)
      root.selectedIndex = activeIndex >= 0 ? activeIndex : 0
    }
  }
}
