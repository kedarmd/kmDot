import QtQuick
import Quickshell.Services.Pipewire
import Quickshell.Io
import qs
import "../components"

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
    if (muted) return "\uEEE8"
    if (volume <= 0.333) return ""
    if (volume <= 0.666) return ""
    return ""
  }

  readonly property string text: muted
    ? icon + " Mute"
    : icon + " " + Math.round(volume * 100) + "%"

  ModulePill {
    id: pill
    anchors.centerIn: parent
    width: label.implicitWidth + 20
    height: 30
    active: root.muted
    fill: Tokens.warningContainer
    hovered: mouse.containsMouse
    pressed: mouse.pressed

    Text {
      id: label
      anchors.centerIn: parent
      text: root.text
      font.family: "JetBrainsMono Nerd Font Propo"
      font.pixelSize: 14
      color: root.muted ? Tokens.on_warning_container : Colors.text_alt
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    onClicked: {
      if (mouse.button === Qt.RightButton) {
        if (root.audio) root.audio.muted = !root.audio.muted
      } else {
        toggleProc.exec(["sh", "-c", "$HOME/.config/kmdot/quickshell/scripts/toggle.sh kmdot-volume"])
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
    id: toggleProc
  }
}
