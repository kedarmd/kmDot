import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Io
import qs
import "../components"
import "../components/popuppos.js" as Pos

// Theme-aware recording feedback with a live peak meter from PipeWire.
PanelWindow {
  id: root
  property var micSamples: Array(32).fill(0)
  property int elapsedSeconds: 0
  property string meterTarget: ""
  property string transientError: ""
  readonly property var waveformProfile: [
    0.18, 0.27, 0.39, 0.56, 0.72, 0.48, 0.31, 0.61,
    0.86, 0.68, 0.42, 0.55, 0.94, 0.74, 0.38, 0.52,
    0.79, 0.62, 0.34, 0.47, 0.88, 0.69, 0.41, 0.57,
    0.76, 0.51, 0.29, 0.44, 0.67, 0.48, 0.31, 0.20
  ]
  readonly property bool recording: HexStore.active && /record|dictat/i.test(HexStore.activityState)
  readonly property bool transcribing: HexStore.active && !root.recording
  readonly property bool hudVisible: root.recording || root.transcribing || root.transientError !== ""
  readonly property string stateText: root.transientError !== "" ? "Dictation error"
    : root.transcribing ? "Transcribing" : "Recording"

  visible: hudVisible
  color: "transparent"
  focusable: false
  screen: Pos.focusedWorkspaceScreen(Quickshell.screens, Hyprland.monitorFor,
    Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.monitor : Hyprland.focusedMonitor)
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.exclusionMode: ExclusionMode.Ignore
  anchors { top: true; bottom: true; left: true; right: true }

  function startMeter() {
    const source = Pipewire.defaultAudioSource
    const name = source ? String(source.name || "") : ""
    if (!root.recording || name === "") { root.stopMeter(); return }
    if (meterProc.running && root.meterTarget === name) return
    root.stopMeter()
    root.meterTarget = name
    meterProc.exec(["node", Quickshell.env("HOME") + "/.config/kmdot/quickshell/scripts/mic-level.mjs", name, "--history"])
  }

  function stopMeter() {
    meterProc.running = false
    root.meterTarget = ""
    root.micSamples = Array(32).fill(0)
  }

  function refreshState() {
    if (root.recording) {
      if (!recordingTimer.running) {
        root.elapsedSeconds = 0
        recordingTimer.start()
      }
      root.transientError = ""
      root.startMeter()
    } else {
      recordingTimer.stop()
      root.stopMeter()
      if (root.transcribing) root.transientError = ""
    }
  }

  Connections {
    target: HexStore
    function onActivityStateChanged() { root.refreshState() }
    function onErrorTextChanged() {
      if (HexStore.errorText !== "") {
        root.transientError = HexStore.errorText
        errorTimer.restart()
      } else if (!HexStore.active) {
        root.transientError = ""
      }
    }
  }

  Connections {
    target: Pipewire
    function onDefaultAudioSourceChanged() { if (root.recording) root.startMeter() }
  }

  Timer {
    id: recordingTimer
    interval: 1000
    repeat: true
    onTriggered: root.elapsedSeconds++
  }
  Timer {
    id: errorTimer
    interval: 2200
    onTriggered: root.transientError = ""
  }
  Process {
    id: meterProc
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function(data) {
        try {
          const samples = JSON.parse(String(data).trim())
          if (Array.isArray(samples) && samples.length === 32)
            root.micSamples = samples.map(value => Math.max(0, Math.min(1, Number(value) || 0)))
        } catch (e) {}
      }
    }
    onExited: root.micSamples = Array(32).fill(0)
  }

  Component.onCompleted: root.refreshState()
  Component.onDestruction: root.stopMeter()

  Rectangle {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 90
    width: Math.min(420, parent.width - 32)
    height: root.transientError !== "" ? 96 : 88
    radius: 20
    color: Colors.surface_high
    border.color: Colors.outline_variant
    border.width: 1
    opacity: root.hudVisible ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Tokens.motionFast; easing.type: Tokens.motionEasing } }

    Item {
      anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 18; rightMargin: 18; topMargin: 14 }
      height: 26
      R1Icon {
        id: stateIcon
        width: 24; height: 24
        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
        glyph: root.transientError !== "" ? "\uf071" : root.recording ? "\uf130" : "\uf110"
        font.family: "JetBrainsMono Nerd Font Propo"
        font.pixelSize: 19
        color: root.transientError !== "" ? Colors.error : Colors.primary
        visible: !root.transcribing
      }
      Canvas {
        id: transcribeSpinner
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 20; height: 20
        visible: root.transcribing
        onPaint: {
          const context = getContext("2d")
          context.clearRect(0, 0, width, height)
          context.beginPath()
          context.arc(width / 2, height / 2, 7, -Math.PI / 2, Math.PI * 1.16)
          context.strokeStyle = Colors.primary.toString()
          context.lineWidth = 2.4
          context.lineCap = "round"
          context.stroke()
        }
        Component.onCompleted: requestPaint()
        NumberAnimation on rotation {
          from: 0; to: 360; duration: 1250; loops: Animation.Infinite
          easing.type: Easing.Linear
          running: root.transcribing && !Tokens.reducedMotion
        }
      }
      Text {
        anchors.left: stateIcon.right; anchors.leftMargin: 10
        anchors.right: timeText.left; anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: root.stateText
        color: Colors.text
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 13
        font.weight: Font.DemiBold
        elide: Text.ElideRight
      }
      Text {
        id: timeText
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: root.recording
          ? Math.floor(root.elapsedSeconds / 60) + ":" + String(root.elapsedSeconds % 60).padStart(2, "0")
          : root.transientError !== "" ? "Check Hex" : ""
        color: root.transientError !== "" ? Colors.error : Colors.text_alt
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 12
      }
    }

    Row {
      id: waveform
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 18
      width: (32 * 3) + (31 * 3)
      height: 22
      spacing: 3
      visible: root.recording
      Repeater {
        model: 32
        delegate: Rectangle {
          required property int index
          readonly property real sample: Number(root.micSamples[index] || 0)
          readonly property real envelope: Math.min(1, sample)
          width: 3
          height: 2 + envelope * 18
          anchors.verticalCenter: parent.verticalCenter
          radius: 2
          color: Colors.primary
          // Ease the measured mic peaks just enough to reduce jitter without masking speech changes.
          Behavior on height {
            NumberAnimation {
              duration: Tokens.reducedMotion ? 0 : 140
              easing.type: Easing.OutCubic
            }
          }
          Behavior on color { ColorAnimation { duration: Tokens.motionFast; easing.type: Tokens.motionEasing } }
        }
      }
    }

    Row {
      id: transcribingWaveform
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 18
      width: (32 * 3) + (31 * 3)
      height: 22
      spacing: 3
      visible: root.transcribing
      Repeater {
        model: root.waveformProfile.length
        delegate: Rectangle {
          id: bar
          required property int index
          property real pulse: 0.72
          width: 3
          height: Math.max(3, Math.min(20, 2 + root.waveformProfile[index] * 18 * pulse))
          anchors.verticalCenter: parent.verticalCenter
          radius: 2
          color: Colors.primary
          Behavior on height {
            NumberAnimation { duration: 180; easing.type: Easing.InOutSine }
          }
          Timer {
            running: root.transcribing && !Tokens.reducedMotion
            repeat: true
            interval: 140 + Math.random() * 240
            onTriggered: {
              bar.pulse = 0.4 + Math.random() * 1.1
              interval = 140 + Math.random() * 240
            }
          }
        }
      }
    }

    Text {
      anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 20; rightMargin: 20; bottomMargin: 18 }
      visible: root.transientError !== ""
      text: root.transientError
      color: Tokens.errorText
      font.family: "JetBrainsMono Nerd Font"
      font.pixelSize: 10
      elide: Text.ElideRight
    }
  }
}
