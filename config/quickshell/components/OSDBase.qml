import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Hyprland
import qs
import "./popuppos.js" as Pos

// Shared, short-lived on-screen display for media-key feedback.
PanelWindow {
  id: root
  required property string sockName
  required property string kind // "volume", "brightness", or "microphone"
  property bool opened: false
  property int hideDelay: 1400
  property real brightnessAmount: DisplayState.barPercent / 100
  readonly property var audioNode: kind === "microphone" ? Pipewire.defaultAudioSource : Pipewire.defaultAudioSink
  readonly property real amount: kind === "volume" || kind === "microphone"
    ? Math.max(0, Math.min(1, (root.audioNode?.audio?.volume ?? 0)))
    : Math.max(0, Math.min(1, brightnessAmount))
  readonly property bool isMuted: (kind === "volume" || kind === "microphone") && (root.audioNode?.audio?.muted ?? false)
  readonly property string iconName: {
    if (kind === "brightness") return "sun"
    if (kind === "microphone") return isMuted ? "mic-off" : "mic"
    if (isMuted || amount <= 0.01) return "audio-off"
    if (amount <= 0.333) return "audio-low"
    if (amount <= 0.666) return "audio-medium"
    return "audio"
  }

  visible: opened
  color: "transparent"
  focusable: false
  screen: Pos.focusedWorkspaceScreen(Quickshell.screens, Hyprland.monitorFor,
    Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.monitor : Hyprland.focusedMonitor)
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.exclusionMode: ExclusionMode.Ignore
  anchors { top: true; bottom: true; left: true; right: true }

  function show() {
    root.opened = true
    if (root.kind === "brightness") brightnessProc.exec(["sh", "-c", "max=$(brightnessctl max 2>/dev/null); cur=$(brightnessctl get 2>/dev/null); if [ -n \"$max\" ] && [ \"$max\" -gt 0 ]; then printf '%s\\n' $((cur * 100 / max)); fi"])
    hideTimer.restart()
  }

  Process {
    id: brightnessProc
    stdout: SplitParser {
      onRead: data => {
        const n = Number(data.trim())
        if (Number.isFinite(n)) root.brightnessAmount = Math.max(0, Math.min(100, n)) / 100
      }
    }
  }

  Timer {
    id: hideTimer
    interval: root.hideDelay
    onTriggered: root.opened = false
  }

  SocketServer {
    active: true
    path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/" + root.sockName + ".sock"
    handler: Socket { onConnectedChanged: if (connected) root.show() }
  }

  Rectangle {
    id: card
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 90
    width: Math.min(360, parent.width - 32)
    height: 84
    radius: 20
    color: Colors.surface_high
    border.color: Colors.outline_variant
    border.width: 1
    opacity: root.opened ? 1 : 0

    Behavior on opacity { NumberAnimation { duration: Tokens.motionFast; easing.type: Tokens.motionEasing } }

    R1Icon {
      id: glyph
      anchors { left: parent.left; leftMargin: 20; top: parent.top; topMargin: 16 }
      width: 24
      height: 24
      iconName: root.iconName
      font.pixelSize: 24
      color: root.isMuted ? Colors.warning : Colors.primary
    }

    Text {
      anchors { left: glyph.right; leftMargin: 12; verticalCenter: glyph.verticalCenter }
      text: root.kind === "volume" ? "Volume" : root.kind === "microphone" ? "Microphone" : "Brightness"
      color: Colors.text_alt
      font.family: "JetBrainsMono Nerd Font"
      font.pixelSize: 13
      font.weight: Font.Medium
    }
    Text {
      anchors { right: parent.right; rightMargin: 20; verticalCenter: glyph.verticalCenter }
      text: root.isMuted ? "Muted" : root.kind === "microphone" ? "On" : Math.round(root.amount * 100) + "%"
      color: Colors.text
      font.family: "JetBrainsMono Nerd Font"
      font.pixelSize: 16
      font.weight: Font.DemiBold
    }
    Rectangle {
      anchors { left: parent.left; leftMargin: 20; right: parent.right; rightMargin: 20; bottom: parent.bottom; bottomMargin: 18 }
      height: 6
      radius: 3
      color: Colors.slider_track
      Rectangle {
        width: parent.width * (root.isMuted ? 0 : root.amount)
        height: parent.height
        radius: parent.radius
        color: Colors.primary
        Behavior on width { NumberAnimation { duration: Tokens.motionFast; easing.type: Tokens.motionEasing } }
      }
    }
  }
}
