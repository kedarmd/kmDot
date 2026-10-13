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
    const fields = String(line).replace(/[\r\n]+$/, "").split("\t")
    if (fields.length < 19) return
    const roleNames = ["base", "surface", "surface_alt", "surface_high", "surface_highest",
      "primary_container", "on_primary_container", "text", "text_alt", "muted", "border",
      "primary", "primary_alt", "accent", "success", "warning", "error"]
    const palette = {}
    for (let i = 0; i < roleNames.length; i++) palette[roleNames[i]] = fields[i + 2]
    const active = fields[0] === "ACTIVE"
    const theme = fields[1]
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
    root.runCommand("setsid nohup $HOME/.config/kmdot/theme-switcher/main.sh " + item.theme + " >/dev/null 2>&1 < /dev/null &")
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
