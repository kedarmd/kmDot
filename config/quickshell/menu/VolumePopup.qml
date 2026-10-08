import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs
import "../components"

PopupBase {
  id: root
  sockName: "kmdot-volume"
  cardWidth: 340

  // anchorItem seam: set by the bar module before toggling (see PopupBase).
  property var sinks: []
  property var sources: []

  readonly property var source: Pipewire.defaultAudioSource

  // Keeps every listed node bound. This is load-bearing, not an optimization:
  // an untracked PwNode sits at ready=false with volume 0 and writes silently
  // no-op -- the "mic stuck at 0%, slider does nothing" failure. The output
  // rows only ever worked because modules/Audio.qml tracks the default sink;
  // nothing tracked the source nodes. Binding re-evaluates on every rebuild
  // (both arrays are reassigned), so hot-plugged devices get bound too.
  PwObjectTracker {
    objects: root.sinks.concat(root.sources)
  }

  // Two device sections now share one card, so each list shows ~2.4 rows and
  // scrolls past that. Without a shared cap the card can grow past the screen
  // height (bar offset 48 + two 330px lists + NowPlaying).
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
    if (!root.sameIds(arr, root.sinks)) root.sinks = arr
  }

  function rebuildSources() {
    const all = Pipewire.nodes.values ? Pipewire.nodes.values : []
    const arr = all.filter(n => root.isMicNode(n))
    root.sortDevices(arr)
    if (!root.sameIds(arr, root.sources)) root.sources = arr
  }

  function refreshItems() {
    root.rebuildSinks()
    root.rebuildSources()
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

  function openedChange() { if (root.opened) root.startMeter(); else root.stopMeter() }
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
    onTriggered: { root.rebuildSinks(); root.rebuildSources(); root.startMeter() }
  }

  // Card body content (fed to the base Column via the default alias).

        NowPlaying {
          id: nowPlaying
        }

        Rectangle {
          visible: nowPlaying.visible
          width: parent.width
          height: 1
          color: Tokens.divider
        }

        Text {
          width: parent.width
          text: "Output devices"
          font.family: "JetBrainsMono Nerd Font Propo"
          font.pixelSize: 12
          color: Colors.muted
        }

        Text {
          width: parent.width
          visible: root.sinks.length === 0
          text: "No output devices"
          font.family: "JetBrainsMono Nerd Font Propo"
          font.pixelSize: 12
          color: Colors.muted
        }

        ListView {
          id: sinkList
          width: parent.width
          height: Math.min(root.sinks.length * 72 + 8, root.listMaxHeight)
          clip: true
          spacing: 8
          model: root.sinks
          interactive: true
          flickDeceleration: 2000
          boundsBehavior: Flickable.StopAtBounds

          Rectangle {
            id: vBar
            visible: sinkList.contentHeight > sinkList.height
            width: 4
            radius: 2
            color: Colors.text_alt
            opacity: 0.4
            anchors.right: parent.right
            anchors.rightMargin: 2
            y: sinkList.contentY * (sinkList.height - vBar.height) / Math.max(1, sinkList.contentHeight - sinkList.height)
            height: Math.max(20, sinkList.height * sinkList.height / sinkList.contentHeight)
          }

          delegate: Item {
            id: row
            required property var modelData
            width: sinkList.width
            height: 64

            readonly property var n: row.modelData
            readonly property var aud: row.n.audio
            readonly property real vol: row.aud ? row.aud.volume : 0
            readonly property bool mut: row.aud ? row.aud.muted : false
            readonly property bool active: row.n === Pipewire.defaultAudioSink

            readonly property string name: row.n.description || row.n.nickname || row.n.name || ""

            readonly property string typeGlyph: {
              const props = row.n.properties || {}
              if (props["device.api"] === "bluez5") return "󰂯"
              const dn = String(props["device.name"] || row.n.name || "")
              if (dn.indexOf("hdmi") >= 0 || dn.indexOf("dp-") >= 0 || dn.indexOf("display") >= 0) return "\uf26c"
              return "󰕾"
            }

            Rectangle {
              anchors.fill: parent
              radius: 14
              color: row.active ? Tokens.primaryContainer : "transparent"
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: Pipewire.preferredDefaultAudioSink = row.n
            }

            Column {
              anchors {
                top: parent.top
                bottom: parent.bottom
                left: parent.left
                right: parent.right
                topMargin: 10
                bottomMargin: 12
                leftMargin: 10
                rightMargin: 10
              }
              spacing: 8

              Row {
                width: parent.width
                spacing: 8

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: row.typeGlyph
                  font.family: "JetBrainsMono Nerd Font Propo"
                  font.pixelSize: 15
                  color: row.active ? Tokens.on_primary_container : Colors.muted
                }

                Rectangle {
                  anchors.verticalCenter: parent.verticalCenter
                  visible: row.active
                  width: 6
                  height: 6
                  radius: 3
                  color: Tokens.primary
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width - 70
                  text: row.name
                  font.family: "JetBrainsMono Nerd Font Propo"
                  font.pixelSize: 12
                  color: row.active ? Tokens.on_primary_container : Colors.text_alt
                  elide: Text.ElideMiddle
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: Math.round(row.vol * 100) + "%"
                  font.family: "JetBrainsMono Nerd Font Propo"
                  font.pixelSize: 12
                  color: row.mut ? Colors.warning : Colors.muted
                }
              }

              Row {
                width: parent.width
                spacing: 10

                SliderBar {
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width - 26
                  height: 11
                  barRadius: 3
                  trackColor: row.active ? Tokens.outlineVariant : Colors.surface_alt
                  value: row.vol
                  onChanged: if (row.aud) row.aud.volume = v
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.verticalCenterOffset: 0
                  text: row.mut ? "\uEEE8" : "\uf026"
                  font.family: "JetBrainsMono Nerd Font Propo"
                  font.pixelSize: 13
                  color: row.mut ? Colors.warning : Colors.text_alt

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (row.aud) row.aud.muted = !row.aud.muted
                  }
                }
              }
            }
          }
        }

        Rectangle {
          width: parent.width
          height: 1
          color: Tokens.divider
        }

        Text {
          width: parent.width
          text: "Input devices"
          font.family: "JetBrainsMono Nerd Font Propo"
          font.pixelSize: 12
          color: Colors.muted
        }

        // Live level of the default mic: thin pavucontrol-style bar that
        // bounces as you speak. Meters the selected mic only (one capture),
        // so it hides when there is nothing to meter.
        Row {
          width: parent.width
          spacing: 8
          visible: root.sources.length > 0

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: ""
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 12
            color: root.micLevel > 0.02 ? Colors.success : Colors.muted
          }

          Rectangle {
            id: meterTrack
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 22
            height: 6
            radius: 3
            color: Colors.surface_alt

            Rectangle {
              anchors { left: parent.left; verticalCenter: parent.verticalCenter }
              width: meterTrack.width * root.micLevel
              height: parent.height
              radius: parent.radius
              color: Tokens.primary

              Behavior on width { NumberAnimation { duration: 80 } }
            }
          }
        }

        Text {
          width: parent.width
          visible: root.sources.length === 0
          text: "No input devices"
          font.family: "JetBrainsMono Nerd Font Propo"
          font.pixelSize: 12
          color: Colors.muted
        }

        ListView {
          id: sourceList
          width: parent.width
          height: Math.min(root.sources.length * 72 + 8, root.listMaxHeight)
          clip: true
          spacing: 8
          model: root.sources
          interactive: true
          flickDeceleration: 2000
          boundsBehavior: Flickable.StopAtBounds

          Rectangle {
            id: srcBar
            visible: sourceList.contentHeight > sourceList.height
            width: 4
            radius: 2
            color: Colors.text_alt
            opacity: 0.4
            anchors.right: parent.right
            anchors.rightMargin: 2
            y: sourceList.contentY * (sourceList.height - srcBar.height) / Math.max(1, sourceList.contentHeight - sourceList.height)
            height: Math.max(20, sourceList.height * sourceList.height / sourceList.contentHeight)
          }

          delegate: Item {
            id: micRow
            required property var modelData
            width: sourceList.width
            height: 64

            readonly property var n: micRow.modelData
            readonly property var aud: micRow.n.audio
            readonly property real vol: micRow.aud ? micRow.aud.volume : 0
            readonly property bool mut: micRow.aud ? micRow.aud.muted : false
            readonly property bool active: micRow.n === Pipewire.defaultAudioSource

            readonly property string name: micRow.n.description || micRow.n.nickname || micRow.n.name || ""

            // A headset mic arrives over bluez5, so it gets the same literal
            // bluetooth char the output rows use; everything else gets
            // fa-microphone. Both are embedded as LITERAL characters, never as
            // \uXXXX escapes of 5-hex-digit PUA codepoints (see the glyph
            // footgun in AGENTS.md). md-microphone (U+F04D) was rejected: the
            // font maps that slot to fa-stop, which renders as a square.
            readonly property string typeGlyph: {
              const props = micRow.n.properties || {}
              if (props["device.api"] === "bluez5") return "󰂯"
              return ""
            }

            Rectangle {
              anchors.fill: parent
              radius: 14
              color: micRow.active ? Tokens.primaryContainer : "transparent"
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: Pipewire.preferredDefaultAudioSource = micRow.n
            }

            Column {
              anchors {
                top: parent.top
                bottom: parent.bottom
                left: parent.left
                right: parent.right
                topMargin: 10
                bottomMargin: 12
                leftMargin: 10
                rightMargin: 10
              }
              spacing: 8

              Row {
                width: parent.width
                spacing: 8

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: micRow.typeGlyph
                  font.family: "JetBrainsMono Nerd Font Propo"
                  font.pixelSize: 15
                  color: micRow.active ? Tokens.on_primary_container : Colors.muted
                }

                Rectangle {
                  anchors.verticalCenter: parent.verticalCenter
                  visible: micRow.active
                  width: 6
                  height: 6
                  radius: 3
                  color: Tokens.primary
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width - 70
                  text: micRow.name
                  font.family: "JetBrainsMono Nerd Font Propo"
                  font.pixelSize: 12
                  color: micRow.active ? Tokens.on_primary_container : Colors.text_alt
                  elide: Text.ElideMiddle
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: Math.round(micRow.vol * 100) + "%"
                  font.family: "JetBrainsMono Nerd Font Propo"
                  font.pixelSize: 12
                  color: micRow.mut ? Colors.warning : Colors.muted
                }
              }

              Row {
                width: parent.width
                spacing: 10

                SliderBar {
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width - 26
                  height: 11
                  barRadius: 3
                  trackColor: micRow.active ? Tokens.outlineVariant : Colors.surface_alt
                  value: micRow.vol
                  onChanged: if (micRow.aud) micRow.aud.volume = v
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.verticalCenterOffset: 0
                  text: micRow.mut ? "\uEEE8" : ""
                  font.family: "JetBrainsMono Nerd Font Propo"
                  font.pixelSize: 13
                  color: micRow.mut ? Colors.warning : Colors.text_alt

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (micRow.aud) micRow.aud.muted = !micRow.aud.muted
                  }
                }
              }
            }
          }
        }
}
