import QtQuick
import Quickshell
import "../components"
import qs

LauncherBase {
  id: root

  sockName: "kmdot-system"
  title: "Search power actions…"
  headerTitle: "System"
  cardHeight: 584
  footerHint: "\u2191\u2193 navigate \u00b7 \u23ce open"
  property string pendingCommand: ""

  items: [
    { label: "Lock", subtitle: "Keep your session private", glyph: "\uf023", shortcutTarget: "exec:~/.config/kmdot/quickshell/scripts/lock-screen.sh", command: "~/.config/kmdot/quickshell/scripts/lock-screen.sh" },
    { label: "Suspend", subtitle: "Resume right where you left off", glyph: "\uf186", shortcutTarget: "exec:systemctl suspend", command: "systemctl suspend" },
    { label: "Log out", subtitle: "End this session", glyph: "\uf08b", shortcutTarget: "dsp:exit", command: "hyprctl dispatch 'hl.dsp.exit()'" },
    { label: "Restart", subtitle: "Restart your laptop", glyph: "\uf021", shortcutTarget: "exec:systemctl reboot", command: "systemctl reboot" },
    { label: "Shut down", subtitle: "Power off your laptop", glyph: "\uf011", shortcutTarget: "exec:systemctl poweroff", command: "systemctl poweroff", confirmShutdown: true }
  ]

  onActivated: function(item) {
    if (item.confirmShutdown) {
      // Power off is only reachable through the explicit confirmation button.
      // If the shared popup is unavailable, fail closed instead of running it.
      if (!root.scope || !root.scope.confirmPopup) return
      root.pendingCommand = item.command
      root.scope.confirmPopup.anchorX = -1
      root.scope.confirmPopup.ask("Shut down?", "Your laptop will power off.", {
        confirmText: "Shut down",
        supportingText: "Save any open work before continuing.",
        titleGlyph: "\uf011",
        titleGlyphColor: Colors.primary,
        titleSize: 24,
        messageSize: 20,
        messageWeight: Font.DemiBold,
        buttonTextSize: 14,
        confirmFill: Colors.error_container,
        confirmTextColor: Colors.base,
        topGap: 14,
        actionGap: 56
      })
      return
    }
    if (item.command) root.runCommand(item.command)
  }

  Connections {
    target: root.scope ? root.scope.confirmPopup : null
    function onConfirmed() {
      if (root.pendingCommand) root.runCommand(root.pendingCommand)
      root.pendingCommand = ""
    }
    function onCancelled() { root.pendingCommand = "" }
  }
}
