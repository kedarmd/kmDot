import QtQuick
import Quickshell
import "../components"
import qs

LauncherBase {
  id: root

  sockName: "kmdot-system"
  title: "System"
  footerHint: "\u2191\u2193 navigate \u00b7 \u23ce run \u00b7 esc close"

  items: [
    { label: "Lock", glyph: "\uf023", command: "hyprlock" },
    { label: "Logout", glyph: "\uf08b", command: "hyprctl dispatch 'hl.dsp.exit()'" },
    { label: "Restart", glyph: "\uf021", command: "systemctl reboot" },
    { label: "Shutdown", glyph: "\uf011", command: "systemctl poweroff" },
    { label: "Suspend", glyph: "\uf1f6", command: "systemctl suspend" }
  ]

  onActivated: function(item) {
    if (item.command) root.runCommand(item.command)
  }
}
