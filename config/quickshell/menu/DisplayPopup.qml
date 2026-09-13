import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import "../components"
import "../components/popuppos.js" as Pos

PanelWindow {
  id: root
  visible: root.opened
  color: Qt.rgba(0, 0, 0, 0)
  focusable: true

  BackgroundEffect.blurRegion: Region {
    item: root.contentItem

    Region {
      intersection: Intersection.Subtract
      x: 0
      y: 0
      width: root.width
      height: 42
    }
  }
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
  property var anchorItem: null
  property real anchorGX: -1

  // Pure view over the DisplayState singleton (issue #49): state binds to
  // singleton properties, actions delegate to it. The only Process left
  // here is posProc (popup positioning).
  property var displays: DisplayState.displays
  property var backlightMap: DisplayState.backlightMap
  property int selectedIdx: DisplayState.selectedIdx
  property string currentMode: DisplayState.currentMode
  property string externalPosition: DisplayState.externalPosition

  readonly property string sockPath: {
    const rt = Quickshell.env("XDG_RUNTIME_DIR")
    return (rt ? rt : "/tmp") + "/kmdot-display.sock"
  }

  readonly property var selectedDisplay: DisplayState.selectedDisplay
  readonly property string selectedName: DisplayState.selectedName
  readonly property bool selectedHasBacklight: DisplayState.selectedHasBacklight
  readonly property string selectedDevice: DisplayState.selectedDevice
  readonly property real selectedScale: DisplayState.selectedScale

  readonly property int brightnessCur: DisplayState.curFor(DisplayState.selectedDevice)
  readonly property int brightnessMax: DisplayState.maxFor(DisplayState.selectedDevice)
  readonly property int brightnessPercent: DisplayState.percentFor(DisplayState.selectedDevice)

  function pickScreen() {
    posProc.exec(["sh", "-c", "hyprctl cursorpos"])
  }

  function applyAnchor() {
    if (root.anchorItem) {
      const gx = Pos.globalCenterX(root.anchorItem)
      root.anchorItem = null
      if (gx >= 0) root.anchorGX = gx
    }
    if (root.anchorGX >= 0) {
      const s = Pos.screenFor(Quickshell.screens.values, root.anchorGX)
      if (s) root.screen = s
      else root.pickScreen()
    } else {
      root.pickScreen()
    }
  }

  function open() {
    if (root.scope && root.scope.activeLauncher) root.scope.activeLauncher.closeLauncher()
    if (root.scope && root.scope.batteryPopup) root.scope.batteryPopup.close()
    if (root.scope && root.scope.volumePopup) root.scope.volumePopup.close()
    if (root.scope && root.scope.calendarPopup) root.scope.calendarPopup.close()
    if (root.scope && root.scope.serverModeDropdown) root.scope.serverModeDropdown.close()
    root.opened = true
    DisplayState.monitorsActive = true
    DisplayState.refreshDisplays()
    DisplayState.detectBacklights()
    root.applyAnchor()
    focusTimer.start()
  }

  function close() {
    DisplayState.monitorsActive = false
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
      height: Math.min(body.implicitHeight + 32, 600)
      radius: 20
      color: Tokens.surfaceContainerLow

      anchors {
        top: parent.top
        topMargin: 48
      }
      x: root.anchorGX >= 0
        ? Pos.cardXFor(root.anchorGX, card.width, root.screen)
        : parent.width - card.width - 10

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
        spacing: 14

        // Header
        Row {
          width: parent.width
          spacing: 10

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "\uf26c"
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 26
            color: Colors.primary
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Display"
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 26
            font.weight: Font.DemiBold
            color: Colors.text
          }
        }

        Rectangle {
          width: parent.width
          height: 1
          color: Tokens.divider
        }

        // Display selector
        Text {
          width: parent.width
          text: "Displays"
          font.family: "JetBrainsMono Nerd Font Propo"
          font.pixelSize: 12
          color: Colors.muted
        }

        Text {
          width: parent.width
          visible: root.displays.length === 0
          text: "No displays detected"
          font.family: "JetBrainsMono Nerd Font Propo"
          font.pixelSize: 12
          color: Colors.muted
        }

        Repeater {
          model: root.displays

          Rectangle {
            required property var modelData
            required property int index
            width: body.width
            height: 48
            radius: 12
            color: index === root.selectedIdx ? Tokens.primaryContainer : "transparent"

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: DisplayState.selectedIdx = index
            }

            Row {
              anchors.fill: parent
              anchors.margins: 8
              spacing: 8

              Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - scaleCol.width - 8

                Text {
                  text: modelData.name + (modelData.focused ? " (active)" : "")
                  font.family: "JetBrainsMono Nerd Font Propo"
                  font.pixelSize: 13
                  font.weight: modelData.focused ? Font.DemiBold : Font.Normal
                  color: index === root.selectedIdx ? Tokens.on_primary_container : Colors.text
                  elide: Text.ElideRight
                  width: parent.width
                }

                Text {
                  text: modelData.width + "x" + modelData.height + "@" + modelData.refresh + " \u00d7 " + modelData.scale
                  font.family: "JetBrainsMono Nerd Font Propo"
                  font.pixelSize: 11
                  color: Colors.muted
                }
              }

              Column {
                id: scaleCol
                anchors.verticalCenter: parent.verticalCenter

                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  visible: root.backlightMap[modelData.name] !== undefined
                  text: "\uf185"
                  font.family: "JetBrainsMono Nerd Font Propo"
                  font.pixelSize: 12
                  color: Colors.muted
                }

                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  visible: root.backlightMap[modelData.name] === undefined
                  text: "\uf059"
                  font.family: "JetBrainsMono Nerd Font Propo"
                  font.pixelSize: 12
                  color: Colors.muted
                }
              }
            }
          }
        }

        // Brightness section
        Rectangle {
          width: parent.width
          height: 1
          color: Tokens.divider
          visible: root.selectedHasBacklight
        }

        Column {
          width: parent.width
          visible: root.selectedHasBacklight
          spacing: 8

          Row {
            width: parent.width
            spacing: 8

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: root.brightnessPercent + "%"
              font.family: "JetBrainsMono Nerd Font Propo"
              font.pixelSize: 14
              font.weight: Font.DemiBold
              color: Colors.text
            }

            Item { width: 1; height: 1 }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "Brightness"
              font.family: "JetBrainsMono Nerd Font Propo"
              font.pixelSize: 12
              color: Colors.muted
            }
          }

          SliderBar {
            width: parent.width
            value: root.brightnessMax > 0 ? root.brightnessCur / root.brightnessMax : 0
            onChanged: DisplayState.applyBrightness(root.selectedDevice, Math.round(v * root.brightnessMax))
          }
        }

        Text {
          width: parent.width
          visible: !root.selectedHasBacklight && root.selectedDisplay !== null
          text: "No backlight control for this display"
          font.family: "JetBrainsMono Nerd Font Propo"
          font.pixelSize: 12
          color: Colors.muted
        }

        // Scale section
        Rectangle {
          width: parent.width
          height: 1
          color: Tokens.divider
        }

        Text {
          width: parent.width
          text: "Scale"
          font.family: "JetBrainsMono Nerd Font Propo"
          font.pixelSize: 12
          color: Colors.muted
        }

        Row {
          width: parent.width
          spacing: 8

          Repeater {
            model: [1.0, 1.25, 1.5, 2.0]

            PillButton {
              required property var modelData
              required property int index
              width: (body.width - 24) / 4
              height: 30
              filled: true
              active: root.selectedScale === modelData
              text: modelData + "\u00d7"
              textSize: 12
              onClicked: DisplayState.applyScale(root.selectedName, modelData)
            }
          }
        }

        Text {
          width: parent.width
          visible: root.selectedDisplay !== null
          text: {
            if (!root.selectedDisplay) return ""
            const w = Math.round(root.selectedDisplay.width / root.selectedScale)
            const h = Math.round(root.selectedDisplay.height / root.selectedScale)
            return "Effective: " + w + "x" + h
          }
          font.family: "JetBrainsMono Nerd Font Propo"
          font.pixelSize: 11
          color: Colors.muted
        }

        // Mode section
        Rectangle {
          width: parent.width
          height: 1
          color: Tokens.divider
        }

        Text {
          width: parent.width
          text: "Display mode"
          font.family: "JetBrainsMono Nerd Font Propo"
          font.pixelSize: 12
          color: Colors.muted
        }

        Row {
          width: parent.width
          spacing: 8

          PillButton {
            width: (body.width - 16) / 3
            height: 30
            filled: true
            active: root.currentMode === "extend"
            text: "Extend"
            textSize: 12
            onClicked: DisplayState.applyMode("extend")
          }

          PillButton {
            width: (body.width - 16) / 3
            height: 30
            filled: true
            active: root.currentMode === "mirror"
            text: "Mirror"
            textSize: 12
            onClicked: DisplayState.applyMode("mirror")
          }

          PillButton {
            width: (body.width - 16) / 3
            height: 30
            filled: true
            active: root.currentMode === "external"
            text: "External"
            textSize: 12
            onClicked: DisplayState.applyMode("external")
          }
        }

        // External position selector (only show in extend mode)
        Column {
          width: parent.width
          visible: root.currentMode === "extend"
          spacing: 8

          Text {
            width: parent.width
            text: "External monitor position"
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 12
            color: Colors.muted
          }

          Row {
            width: parent.width
            spacing: 8

            PillButton {
              width: (body.width - 8) / 2
              height: 30
              filled: true
              active: root.externalPosition === "left"
              text: "← Left"
              textSize: 12
              onClicked: {
                DisplayState.externalPosition = "left"
                DisplayState.applyMode("extend")
              }
            }

            PillButton {
              width: (body.width - 8) / 2
              height: 30
              filled: true
              active: root.externalPosition === "right"
              text: "Right →"
              textSize: 12
              onClicked: {
                DisplayState.externalPosition = "right"
                DisplayState.applyMode("extend")
              }
            }
          }
        }
      }
    }
  }
}
