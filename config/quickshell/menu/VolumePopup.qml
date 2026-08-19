import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import qs
import "../components"

PanelWindow {
  id: root
  visible: root.opened
  color: Qt.rgba(0, 0, 0, 0)
  focusable: true
  screen: Quickshell.screens.values.length > 0 ? Quickshell.screens.values[0] : null

  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
  WlrLayershell.exclusionMode: ExclusionMode.Ignore

  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }

  property bool opened: false
  property var scope: null
  property var sinks: []

  readonly property string sockPath: {
    const rt = Quickshell.env("XDG_RUNTIME_DIR")
    return (rt ? rt : "/tmp") + "/kmdot-volume.sock"
  }

  readonly property var sink: Pipewire.defaultAudioSink
  readonly property var audio: root.sink ? root.sink.audio : null
  readonly property real volume: root.audio ? root.audio.volume : 0
  readonly property bool muted: root.audio ? root.audio.muted : false
  readonly property string headerIcon: root.muted ? "\uEEE8" : "\uf026"

  function rebuildSinks() {
    const all = Pipewire.nodes.values ? Pipewire.nodes.values : []
    const arr = all.filter(n => n && n.isSink && !n.isStream)
    arr.sort((a, b) => {
      const aAct = a === Pipewire.defaultAudioSink
      const bAct = b === Pipewire.defaultAudioSink
      if (aAct !== bAct) return aAct ? -1 : 1
      return (a.description || "").localeCompare(b.description || "")
    })
    root.sinks = arr
  }

  function pickScreen() {
    posProc.exec(["sh", "-c", "hyprctl cursorpos"])
  }

  function open() {
    if (root.scope && root.scope.activeLauncher) root.scope.activeLauncher.closeLauncher()
    if (root.scope && root.scope.batteryPopup) root.scope.batteryPopup.close()
    if (root.scope && root.scope.volumePopup && root.scope.volumePopup !== root) root.scope.volumePopup.close()
    if (root.scope && root.scope.brightnessPopup && root.scope.brightnessPopup !== root) root.scope.brightnessPopup.close()
    if (root.scope && root.scope.calendarPopup) root.scope.calendarPopup.close()
    if (root.scope && root.scope.serverModeDropdown) root.scope.serverModeDropdown.close()
    root.opened = true
    root.rebuildSinks()
    root.pickScreen()
    focusTimer.start()
  }

  function close() {
    root.opened = false
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  SocketServer {
    active: true
    path: root.sockPath
    handler: Socket {
      onConnectedChanged: {
        if (connected) root.toggle()
      }
    }
  }

  Timer {
    id: focusTimer
    interval: 60
    repeat: true
    onTriggered: {
      if (!root.opened) {
        focusTimer.stop()
        return
      }
      content.forceActiveFocus()
      if (content.activeFocus) focusTimer.stop()
    }
  }

  Timer {
    interval: 3000
    repeat: true
    running: root.opened
    onTriggered: root.rebuildSinks()
  }

  Process {
    id: posProc
    stdout: StdioCollector {
      onStreamFinished: {
        const m = /(-?\d+),\s*(-?\d+)/.exec(String(this.text).trim())
        if (!m) return
        const X = parseInt(m[1], 10)
        const Y = parseInt(m[2], 10)
        const screens = Quickshell.screens.values
        for (let i = 0; i < screens.length; i++) {
          const s = screens[i]
          if (X >= s.x && X < s.x + s.width && Y >= s.y && Y < s.y + s.height) {
            root.screen = s
            return
          }
        }
      }
    }
  }

  Item {
    id: content
    anchors.fill: parent
    focus: true
    Keys.onEscapePressed: root.close()

    MouseArea {
      id: dismiss
      anchors.fill: parent
      onClicked: root.close()
    }

    Rectangle {
      id: card
      width: 340
      height: body.implicitHeight + 32
      radius: 20
      color: Tokens.surfaceContainerHigh

      anchors {
        top: parent.top
        topMargin: 48
        right: parent.right
        rightMargin: 10
      }

      MouseArea {
        anchors.fill: parent
      }

      Column {
        id: body
        anchors {
          top: parent.top
          left: parent.left
          right: parent.right
          margins: 16
        }
        spacing: 12

        Row {
          width: parent.width
          spacing: 10

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.headerIcon
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 26
            color: root.muted ? Colors.warning : Colors.success
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(root.volume * 100) + "%"
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 26
            font.weight: Font.DemiBold
            color: Colors.text
          }

          Item { width: 1; height: 1 }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.sink ? (root.sink.description || root.sink.nickname || root.sink.name || "") : ""
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 12
            color: Colors.muted
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignRight
            width: Math.min(140, implicitWidth)
          }
        }

        Row {
          width: parent.width
          spacing: 10

          SliderBar {
            id: masterBar
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 74
            value: root.volume
            onChanged: if (root.audio) root.audio.volume = v
          }

          PillButton {
            anchors.verticalCenter: parent.verticalCenter
            width: 64
            active: root.muted
            fillColor: Tokens.errorContainer
            activeTextColor: Tokens.on_error_container
            glyph: root.muted ? "\uEEE8" : "\uf026"
            glyphSize: 11
            text: root.muted ? "Mute" : "Sound"
            textSize: 11
            onClicked: if (root.audio) root.audio.muted = !root.audio.muted
          }
        }

        Rectangle {
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
          height: Math.min(root.sinks.length * 72 + 8, 330)
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
      }
    }
  }
}
