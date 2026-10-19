import QtQuick
import Quickshell.Services.Pipewire
import qs
import "../components"

BarModule {
  id: root
  sock: "kmdot-volume"
  labelSpacing: 0
  smoothIconColor: true

  PwObjectTracker {
    objects: {
      const nodes = []
      if (root.sink) nodes.push(root.sink)
      if (root.source) nodes.push(root.source)
      return nodes
    }
  }

  readonly property var sink: Pipewire.defaultAudioSink
  readonly property var source: Pipewire.defaultAudioSource
  readonly property var audio: sink ? sink.audio : null
  readonly property var micAudio: source ? source.audio : null
  readonly property real volume: audio ? audio.volume : 0
  readonly property bool muted: audio ? audio.muted : false
  readonly property bool micMuted: micAudio ? micAudio.muted : false

  tooltipText: "Volume: " + Math.round(volume * 100) + "%" + (micMuted ? " · Microphone muted" : "")

  glyph: ""
  trailingGlyph: micMuted ? "\uf131" : ""
  trailingColor: Colors.warning
  text: muted ? "Mute" : Math.round(volume * 100) + "%"
  iconName: {
    if (muted || volume <= 0.01) return "audio-off"
    if (volume <= 0.333) return "audio-low"
    if (volume <= 0.666) return "audio-medium"
    return "audio"
  }
  iconForeground: root.muted ? Colors.warning : root.foreground

  onWheeled: wheel => {
    if (!root.audio) return
    var step = 0.02
    if (wheel.angleDelta.y > 0) root.audio.volume = Math.min(1, root.audio.volume + step)
    else root.audio.volume = Math.max(0, root.audio.volume - step)
  }
}
