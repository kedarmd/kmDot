import QtQuick
import Quickshell.Services.Pipewire
import Quickshell.Io
import qs

Item {
  id: root
  implicitHeight: 30
  width: label.implicitWidth + 20
  required property var tooltip

  PwObjectTracker {
    objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
  }

  readonly property var sink: Pipewire.defaultAudioSink
  readonly property var audio: sink ? sink.audio : null
  readonly property real volume: audio ? audio.volume : 0
  readonly property bool muted: audio ? audio.muted : false
  readonly property string tooltipText: "Volume: " + Math.round(volume * 100) + "%"

  readonly property string icon: {
    if (muted) return "󰝟"
    if (volume <= 0.333) return ""
    if (volume <= 0.666) return ""
    return ""
  }

  readonly property string text: muted
    ? icon + " Mute"
    : icon + " " + Math.round(volume * 100) + "%"

  Text {
    id: label
    anchors.centerIn: parent
    text: root.text
    font.family: "JetBrainsMono Nerd Font Propo"
    font.pixelSize: 14
    color: Colors.text_alt
    opacity: root.muted ? 0.4 : 1.0
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    onClicked: {
      if (mouse.button === Qt.RightButton) {
        if (root.audio) root.audio.muted = !root.audio.muted
      } else {
        volumeProc.exec(["pavucontrol"])
      }
    }
    onWheel: {
      if (!root.audio) return
      var step = 0.02
      if (wheel.angleDelta.y > 0) root.audio.volume = Math.min(1, root.audio.volume + step)
      else root.audio.volume = Math.max(0, root.audio.volume - step)
    }
    onEntered: root.tooltip.show(root, root.tooltipText)
    onExited: root.tooltip.hide()
  }

  Process {
    id: volumeProc
  }
}
