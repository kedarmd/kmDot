import QtQuick
import Quickshell.Io
import qs
import "../components"
import "../components/serverstatus.js" as ServerStatus

BarModule {
  id: root
  sock: "kmdot-server"

  property string mode: "off"
  property string inhibitor: "inactive"
  property string tailscale: "inactive"
  property string tailscaleIp: ""
  property string jellyfin: "inactive"

  busy: root.popupRef ? root.popupRef.busy : false

  glyph: ""
  active: root.mode === "on"
  fill: Tokens.successContainer
  on_color: Tokens.on_success_container
  dimmed: !root.busy && root.mode !== "on"
  tooltipText: "Server mode: " + (root.mode === "on" ? "On" : "Off")

  function applyStatus(text) {
    const s = ServerStatus.parseServerStatus(text)
    root.mode = s.mode
    root.inhibitor = s.inhibitor
    root.tailscale = s.tailscale
    root.tailscaleIp = s.tailscaleIp
    root.jellyfin = s.jellyfin
  }

  function refresh() {
    statusProc.exec(["sh", "-c", "$HOME/.config/kmdot/quickshell/scripts/server-mode.sh status"])
  }

  Timer {
    interval: 2000
    running: !root.popupRef || !root.popupRef.opened
    repeat: true
    onTriggered: root.refresh()
  }
  Component.onCompleted: root.refresh()

  Process {
    id: statusProc
    stdout: StdioCollector {
      onStreamFinished: root.applyStatus(String(this.text))
    }
  }
}
