import QtQuick
import Quickshell.Services.Pipewire
import qs

Item {
  id: root
  width: parent.width
  height: 76

  required property var modelData
  property bool isInput: false
  property bool switching: false
  property string cachedDeviceName: ""
  property real cachedLevel: 0
  property bool cachedMuted: false
  property bool cachedActive: false

  readonly property var audioNode: root.modelData
  readonly property var audio: root.audioNode ? root.audioNode.audio : null
  readonly property real level: root.audio ? root.audio.volume : 0
  readonly property bool muted: root.audio ? root.audio.muted : false
  readonly property bool nodeReady: !!(root.audioNode && root.audioNode.ready && root.audio)
  readonly property var defaultNode: root.isInput ? Pipewire.defaultAudioSource : Pipewire.defaultAudioSink
  readonly property bool active: root.audioNode && root.defaultNode
    ? String(root.audioNode.id) === String(root.defaultNode.id) : false
  readonly property bool internal: root.audioNode && root.audioNode.properties
    ? (root.audioNode.properties["device.form-factor"] === "internal"
      || (String(root.audioNode.name || "").indexOf("alsa_") === 0 && String(root.audioNode.name || "").indexOf("pci") >= 0))
    : false
  readonly property string deviceName: root.audioNode
    ? (root.internal ? (root.isInput ? "Built-in microphone" : "Built-in speakers")
      : (root.audioNode.description || root.audioNode.nickname || root.audioNode.name || "")) : ""
  readonly property string shownName: root.nodeReady ? root.deviceName : (root.cachedDeviceName || "Updating device…")
  readonly property real shownLevel: root.nodeReady ? root.level : root.cachedLevel
  readonly property bool shownMuted: root.nodeReady ? root.muted : root.cachedMuted
  readonly property bool shownActive: root.nodeReady ? root.active : root.cachedActive

  function refreshCache() {
    if (!root.nodeReady) return
    if (root.deviceName !== "") root.cachedDeviceName = root.deviceName
    root.cachedLevel = root.level
    root.cachedMuted = root.muted
    root.cachedActive = root.active
  }

  onDeviceNameChanged: root.refreshCache()
  onNodeReadyChanged: root.refreshCache()
  onLevelChanged: root.refreshCache()
  onMutedChanged: root.refreshCache()
  onActiveChanged: {
    root.refreshCache()
    if (root.active) { root.switching = false; switchTimeout.stop() }
  }

  Component.onCompleted: root.refreshCache()

  Timer {
    interval: 120
    repeat: true
    running: !!(root.audioNode && !root.nodeReady)
    onTriggered: root.refreshCache()
  }

  function selectDevice() {
    if (!root.nodeReady) return
    if (!root.active) {
      root.switching = true
      switchTimeout.restart()
    }
    if (root.isInput) Pipewire.preferredDefaultAudioSource = root.audioNode
    else Pipewire.preferredDefaultAudioSink = root.audioNode
  }

  Timer {
    id: switchTimeout
    interval: 5000
    onTriggered: root.switching = false
  }

  // Select from anywhere in the device row. The slider and mute controls are
  // later siblings, so they keep their own pointer handling above this area.
  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: root.selectDevice()
  }

  Row {
    id: nameRow
    width: parent.width
    height: 24

    Text {
      width: parent.width - 56 - ((!root.nodeReady || root.active || root.switching) ? 76 : 0)
      text: root.shownName
      color: root.shownActive ? Colors.text : Colors.text_alt
      font.family: "JetBrainsMono Nerd Font"
      font.pixelSize: 16
      font.weight: Font.DemiBold
      elide: Text.ElideRight
      verticalAlignment: Text.AlignVCenter
    }

    Rectangle {
      width: !root.nodeReady ? 76 : ((root.active || root.switching) ? (root.switching && !root.active ? 76 : 64) : 0)
      height: 20
      radius: 10
      color: root.nodeReady ? Colors.pill : Colors.surface_highest
      visible: !root.nodeReady || root.active || root.switching
      anchors.verticalCenter: parent.verticalCenter

      Text {
        anchors.fill: parent
        text: !root.nodeReady ? "Updating…" : (root.switching && !root.active ? "Switching…" : "Default")
        color: root.nodeReady ? Colors.on_pill : Colors.text_alt
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 12
        font.weight: Font.DemiBold
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
      }
    }

    Text {
      width: 56
      text: Math.round(root.shownLevel * 100) + "%"
      color: root.shownMuted ? Colors.warning : Colors.primary
      font.family: "JetBrainsMono Nerd Font"
      font.pixelSize: 12
      horizontalAlignment: Text.AlignRight
      verticalAlignment: Text.AlignVCenter
    }

  }

  Row {
    y: 36
    width: parent.width
    height: 40
    spacing: 24

    SliderBar {
      width: parent.width - 48
      height: 40
      trackHeight: 8
      barRadius: 4
      thumbVisible: true
      thumbSize: 16
      trackColor: Colors.surface_alt
      fillColor: Colors.primary
      thumbColor: Colors.surface_high
      thumbBorderColor: Colors.primary
      value: root.shownLevel
      opacity: root.nodeReady ? 1 : 0.65
      onChanged: if (root.nodeReady) root.audio.volume = v
    }

    AudioGlyph {
      width: 24
      height: 24
      anchors.verticalCenter: parent.verticalCenter
      isInput: root.isInput
      muted: root.shownMuted
      color: root.shownMuted ? Colors.warning : Colors.text_alt

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: if (root.nodeReady) root.audio.muted = !root.audio.muted
      }
    }
  }
}
