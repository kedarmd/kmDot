import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import qs

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

  visible: opened
  color: "transparent"
  focusable: false
  screen: Quickshell.screens.length ? Quickshell.screens[0] : null
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
    width: 300
    height: 76
    radius: 24
    color: Colors.surface
    border.color: Colors.border
    border.width: 1
    opacity: root.opened ? 1 : 0

    Behavior on opacity { NumberAnimation { duration: Tokens.motionFast; easing.type: Tokens.motionEasing } }

    Text {
      id: glyph
      anchors { left: parent.left; leftMargin: 22; verticalCenter: parent.verticalCenter; verticalCenterOffset: -12 }
      text: root.kind === "microphone"
        ? (root.isMuted ? "\uf131" : "\uf130")
        : root.kind === "volume"
          ? (root.isMuted || root.amount <= 0 ? "\uf026" : root.amount < 0.5 ? "\uf027" : "\uf028")
          : "\uf185"
      color: root.isMuted ? Colors.muted : Colors.primary
      font.family: "JetBrainsMono Nerd Font"
      font.pixelSize: 24
    }

    Text {
      anchors { left: glyph.right; leftMargin: 16; verticalCenter: parent.verticalCenter; verticalCenterOffset: -12 }
      text: root.kind === "volume" ? "Volume" : root.kind === "microphone" ? "Microphone" : "Brightness"
      color: Colors.text_alt
      font.pixelSize: 12
      font.weight: Font.Medium
    }
    Text {
      anchors { right: parent.right; rightMargin: 22; verticalCenter: parent.verticalCenter; verticalCenterOffset: -12 }
      text: root.isMuted ? "Muted" : root.kind === "microphone" ? "On" : Math.round(root.amount * 100) + "%"
      color: Colors.text
      font.pixelSize: 19
      font.weight: Font.DemiBold
    }
    Rectangle {
      anchors { left: glyph.right; leftMargin: 16; right: parent.right; rightMargin: 22; bottom: parent.bottom; bottomMargin: 16 }
      height: 8
      radius: 4
      color: Colors.surface_alt
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
