import QtQuick
import Quickshell.Services.Pipewire
import qs
import "../components"

BarModule {
  id: root
  sock: "kmdot-volume"

  PwObjectTracker {
    objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
  }

  readonly property var sink: Pipewire.defaultAudioSink
  readonly property var audio: sink ? sink.audio : null
  readonly property real volume: audio ? audio.volume : 0
  readonly property bool muted: audio ? audio.muted : false

  tooltipText: "Volume: " + Math.round(volume * 100) + "%"

  glyph: {
    if (muted) return ""
    if (volume <= 0.333) return ""
    if (volume <= 0.666) return ""
    return ""
  }
  text: muted ? "Mute" : Math.round(volume * 100) + "%"
  active: root.muted
  fill: Tokens.warningContainer
  on_color: Tokens.on_warning_container

  onWheeled: wheel => {
    if (!root.audio) return
    var step = 0.02
    if (wheel.angleDelta.y > 0) root.audio.volume = Math.min(1, root.audio.volume + step)
    else root.audio.volume = Math.max(0, root.audio.volume - step)
  }
}
