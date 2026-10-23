import QtQuick
import "../components"

LauncherBase {
  id: root

  sockName: "kmdot-system"
  castStyle: true
  title: "Search power actions…"
  headerTitle: "System"
  cardHeight: 520
  footerHint: "\u2191\u2193 navigate \u00b7 \u23ce open"

  items: [
    { label: "Lock", subtitle: "Keep your session private", glyph: "\uf023", shortcutTarget: "exec:~/.config/kmdot/quickshell/scripts/lock-screen.sh", command: "~/.config/kmdot/quickshell/scripts/lock-screen.sh" },
    { label: "Suspend", subtitle: "Resume right where you left off", glyph: "\uf186", shortcutTarget: "exec:systemctl suspend", command: "systemctl suspend" },
    { label: "Log out", subtitle: "End this session", glyph: "\uf08b", shortcutTarget: "dsp:exit", command: "hyprctl dispatch 'hl.dsp.exit()'" },
    { label: "Restart", subtitle: "Restart your laptop", glyph: "\uf021", shortcutTarget: "exec:systemctl reboot", command: "systemctl reboot" },
    { label: "Shut down", subtitle: "Power off your laptop", glyph: "\uf011", shortcutTarget: "exec:systemctl poweroff", command: "systemctl poweroff" }
  ]

  onActivated: function(item) {
    if (item.command) root.runCommand(item.command)
  }
}
