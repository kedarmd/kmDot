import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs
import "../components"

PopupBase {
  id: root
  sockName: "kmdot-volume"
  cardWidth: 424
  // Match the reviewed launcher card while keeping this device panel's
  // content and controls intact.
  cardRadius: 20
  cardBorderWidth: 1
  cardBorderColor: Colors.outline_variant

  // anchorItem seam: set by the bar module before toggling (see PopupBase).
  property var sinks: []
  property var sources: []
  property bool sinkListRecovering: false
  property bool sourceListRecovering: false

  readonly property var source: Pipewire.defaultAudioSource
  readonly property var availableBluetoothAudioDevices: BluetoothStore.devices.filter(d =>
    d.paired && !d.connected && d.icon === "")

  // Keeps every listed node bound. This is load-bearing, not an optimization:
  // an untracked PwNode sits at ready=false with volume 0 and writes silently
  // no-op -- the "mic stuck at 0%, slider does nothing" failure. The output
  // rows only ever worked because modules/Audio.qml tracks the default sink;
  // nothing tracked the source nodes. Binding re-evaluates on every rebuild
  // (both arrays are reassigned), so hot-plugged devices get bound too.
  PwObjectTracker {
    objects: root.sinks.concat(root.sources)
  }

  // Two device sections share one card. Extra hardware devices scroll inside
  // their short lists so the primary controls stay visible.
  readonly property int listMaxHeight: 176

  // PwNode exposes isSink/isStream but NO isSource, so capture nodes have to be
  // classified off the PwNodeType bitfield. Real bit values, verified against a
  // live node dump on this machine: Audio=1 Video=2 Stream=4 Source=8 Sink=16.
  // The composite members are NOT usable as masks -- AudioSource=9 and
  // AudioSink=17 carry extra bits -- so test the four base flags instead.
  //
  // Audio + Source + !Stream + !Video selects hardware capture nodes only. It
  // rejects app output streams (Stream bit), the V4L2 camera (Video bit), and
  // loopback monitor sources, which PipeWire types Stream/Output/Audio even
  // though PulseAudio lists them under "sources" (pactl list short sources shows
  // alsa_output.*.monitor) -- so they never appear as fake mics.
  function isMicNode(n) {
    if (!n) return false
    const t = n.type
    return (t & PwNodeType.Source) === PwNodeType.Source
      && (t & PwNodeType.Audio) === PwNodeType.Audio
      && (t & PwNodeType.Stream) !== PwNodeType.Stream
      && (t & PwNodeType.Video) !== PwNodeType.Video
  }

  // Compare by node id: the 3s rebuild must NOT reassign the arrays when
  // nothing changed. A reassignment rebuilds every delegate AND resets the
  // PwObjectTracker binding, so all rows blink to 0% (ready=false gap) on
  // every tick. Only real membership/order changes reassign.
  function sameIds(a, b) {
    if (a.length !== b.length) return false
    for (let i = 0; i < a.length; i++) {
      if (!a[i] || !b[i] || a[i].id !== b[i].id) return false
    }
    return true
  }

  // Stable device order: the built-in (internal) device is always pinned
  // first, everything else alphabetical below it — never re-sorted by which
  // device is active (re-sorting on select is disorienting: rows jump under
  // the cursor). form-factor is the semantic signal, but properties populate
  // seconds after the node appears, so the alsa/pci name fallback keeps the
  // order right from the first paint.
  function isInternalNode(n) {
    if (!n) return false
    const props = n.properties || {}
    if (props["device.form-factor"] === "internal") return true
    const nm = String(n.name || "")
    return nm.indexOf("alsa_") === 0 && nm.indexOf("pci") >= 0
  }

  function sortDevices(arr) {
    arr.sort((a, b) => {
      const aIn = root.isInternalNode(a) ? 0 : 1
      const bIn = root.isInternalNode(b) ? 0 : 1
      if (aIn !== bIn) return aIn - bIn
      return (a.description || "").localeCompare(b.description || "")
    })
  }

  function rebuildSinks() {
    const all = Pipewire.nodes.values ? Pipewire.nodes.values : []
    const arr = all.filter(n => n && n.isSink && !n.isStream)
    root.sortDevices(arr)
    if (arr.length === 0 && root.sinks.length > 0) {
      root.sinkListRecovering = true
      sinkEmptyGrace.restart()
      return
    }
    sinkEmptyGrace.stop()
    root.sinkListRecovering = false
    if (!root.sameIds(arr, root.sinks)) root.sinks = arr
  }

  function rebuildSources() {
    const all = Pipewire.nodes.values ? Pipewire.nodes.values : []
    const arr = all.filter(n => root.isMicNode(n))
    root.sortDevices(arr)
    if (arr.length === 0 && root.sources.length > 0) {
      root.sourceListRecovering = true
      sourceEmptyGrace.restart()
      return
    }
    sourceEmptyGrace.stop()
    root.sourceListRecovering = false
    if (!root.sameIds(arr, root.sources)) root.sources = arr
  }

  Timer {
    id: sinkEmptyGrace
    interval: 2500
    onTriggered: { root.sinks = []; root.sinkListRecovering = false }
  }
  Timer {
    id: sourceEmptyGrace
    interval: 2500
    onTriggered: { root.sources = []; root.sourceListRecovering = false }
  }

  function refreshItems() {
    root.rebuildSinks()
    root.rebuildSources()
    BluetoothStore.refresh()
  }

  // Live input-level meter (pavucontrol's bouncing bar). One capture at a
  // time, always the default source: mic-level.mjs folds pw-record's f32
  // stream to a 0..1 line per ~80ms. Lifecycle: start on open, stop on close
  // (leaving a capture running would hold the mic open + show in pavucontrol's
  // Recording tab), restart when the default mic changes, and revive on the
  // 3s tick if the capture died (BT mic dropped). startMeter is a cheap no-op
  // when the right capture is already running, so the tick is safe.
  property real micLevel: 0
  property string meterTarget: ""

  function meterScript() { return Quickshell.env("HOME") + "/.config/kmdot/quickshell/scripts/mic-level.mjs" }

  function startMeter() {
    const src = Pipewire.defaultAudioSource
    const name = src ? String(src.name || "") : ""
    if (name === "") { root.stopMeter(); return }
    if (meterProc.running && root.meterTarget === name) return
    root.stopMeter()
    root.meterTarget = name
    meterProc.exec(["node", root.meterScript(), name])
  }

  function stopMeter() {
    meterProc.running = false
    root.meterTarget = ""
    root.micLevel = 0
  }

  function openedChange() {
    if (root.opened) {
      root.startMeter()
      BluetoothStore.refresh()
      if (BluetoothStore.enabled) BluetoothStore.startDiscovery()
    } else {
      root.stopMeter()
      BluetoothStore.stopDiscovery()
    }
  }
  onSourceChanged: if (root.opened) root.startMeter()

  Process {
    id: meterProc
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function(data) {
        const v = parseFloat(String(data).trim())
        if (!Number.isNaN(v)) root.micLevel = Math.max(0, Math.min(1, v))
      }
    }
    onExited: root.micLevel = 0
  }

  Timer {
    interval: 3000
    repeat: true
    running: root.opened
    onTriggered: { root.rebuildSinks(); root.rebuildSources(); BluetoothStore.refresh(); root.startMeter() }
  }

// Content sizes to the active sections. The two device lists keep
// their own short scroll area, so extra PipeWire devices retain gain and mute.
Column {
  width: parent.width
  spacing: 0

  Row {
    width: parent.width
    height: 36
    spacing: 12
    R1Icon { glyph: "\uf028"; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 20; color: Colors.primary; anchors.verticalCenter: parent.verticalCenter }
    Text { text: "Sound"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 20; font.weight: Font.DemiBold; color: Colors.text; anchors.verticalCenter: parent.verticalCenter }
  }

  Item { width: 1; height: 24 }

  Rectangle {
    visible: nowPlaying.player !== null
    width: parent.width
    height: 176
    radius: 16
    color: Colors.surface_alt
    NowPlaying { id: nowPlaying; anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 } }
  }

  Item { width: 1; height: 24; visible: nowPlaying.player !== null }
  Text { width: parent.width; height: 20; text: "OUTPUT DEVICES"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: Tokens.mutedText; verticalAlignment: Text.AlignVCenter }
  Item { width: 1; height: 20 }

  ListView {
    id: sinkList
    width: parent.width
    height: root.sinks.length > 0 ? Math.min(root.sinks.length * 76 + (root.sinks.length - 1) * 24, root.listMaxHeight) : 24
    clip: true
    spacing: 24
    model: root.sinks
    interactive: true
    flickDeceleration: 2000
    boundsBehavior: Flickable.StopAtBounds
    Text { anchors.centerIn: parent; visible: root.sinks.length === 0; text: root.sinkListRecovering ? "Switching output device…" : "No output devices"; color: Tokens.mutedText; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
    Rectangle {
      visible: sinkList.contentHeight > sinkList.height
      width: 4; radius: 2; color: Colors.text_alt; opacity: 0.4
      anchors.right: parent.right; anchors.rightMargin: 2
      y: sinkList.contentY * (sinkList.height - height) / Math.max(1, sinkList.contentHeight - sinkList.height)
      height: Math.max(20, sinkList.height * sinkList.height / sinkList.contentHeight)
    }
    delegate: AudioDeviceControl { isInput: false }
  }

  Item { width: 1; height: 24 }
  Column {
    width: parent.width
    spacing: 24
    Repeater {
      model: root.availableBluetoothAudioDevices
      delegate: Item {
        required property var modelData
        width: parent.width
        height: 24
        Row {
          width: parent.width
          height: parent.height
          Text { width: parent.width - 80; text: modelData.name; color: Colors.text; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16; font.weight: Font.DemiBold; elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter }
          Text { width: 80; text: "Connect"; color: Colors.text_alt; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; horizontalAlignment: Text.AlignRight; verticalAlignment: Text.AlignVCenter }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: BluetoothStore.activate(modelData) }
      }
    }
  }

  Item { width: 1; height: 20 }
  Rectangle { width: parent.width; height: 1; color: Tokens.divider }
  Item { width: 1; height: 23 }

  Row {
    width: parent.width
    height: 20
  Text { width: parent.width - 164; text: "INPUT DEVICES"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: Tokens.mutedText; verticalAlignment: Text.AlignVCenter }
    Rectangle {
      width: 152; height: 4; radius: 2; anchors.verticalCenter: parent.verticalCenter; color: Tokens.outlineVariant
      Rectangle { width: parent.width * root.micLevel; height: parent.height; radius: parent.radius; color: Colors.success; Behavior on width { NumberAnimation { duration: Tokens.meterMotion; easing.type: Easing.Linear } } }
    }
  }

  Item { width: 1; height: 20 }
  ListView {
    id: sourceList
    width: parent.width
    height: root.sources.length > 0 ? Math.min(root.sources.length * 76 + (root.sources.length - 1) * 24, root.listMaxHeight) : 24
    clip: true
    spacing: 24
    model: root.sources
    interactive: true
    flickDeceleration: 2000
    boundsBehavior: Flickable.StopAtBounds
    Text { anchors.centerIn: parent; visible: root.sources.length === 0; text: root.sourceListRecovering ? "Switching input device…" : "No input devices"; color: Tokens.mutedText; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
    Rectangle {
      visible: sourceList.contentHeight > sourceList.height
      width: 4; radius: 2; color: Colors.text_alt; opacity: 0.4
      anchors.right: parent.right; anchors.rightMargin: 2
      y: sourceList.contentY * (sourceList.height - height) / Math.max(1, sourceList.contentHeight - sourceList.height)
      height: Math.max(20, sourceList.height * sourceList.height / sourceList.contentHeight)
    }
    delegate: AudioDeviceControl { isInput: true }
  }

  Item { width: 1; height: 28; visible: root.availableBluetoothAudioDevices.length > 0 }
  Column {
    width: parent.width
    spacing: 0
    Repeater {
      model: root.availableBluetoothAudioDevices
      delegate: Rectangle {
        required property var modelData
        width: parent.width; height: 72; radius: 16; color: Colors.surface_alt
        R1Icon { x: 16; width: 24; height: 24; anchors.verticalCenter: parent.verticalCenter; glyph: ""; color: Colors.text_alt; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 18; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
        Column {
          x: 56; width: parent.width - 96; anchors.verticalCenter: parent.verticalCenter; spacing: 4
          Text { width: parent.width; text: modelData.name + " microphone"; color: Colors.text; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; font.weight: Font.DemiBold; elide: Text.ElideRight }
          Text { text: "Not connected"; color: Colors.text_alt; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
        }
        R1Icon { anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; glyph: "\uf105"; color: Colors.text_alt; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 18 }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: BluetoothStore.activate(modelData) }
      }
    }
  }

}
}
