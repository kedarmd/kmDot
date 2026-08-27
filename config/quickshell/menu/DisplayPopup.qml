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

  property var displays: []
  property var backlightMap: ({})
  property int selectedIdx: 0
  property string currentMode: "extend"

  readonly property string sockPath: {
    const rt = Quickshell.env("XDG_RUNTIME_DIR")
    return (rt ? rt : "/tmp") + "/kmdot-display.sock"
  }

  readonly property var selectedDisplay: {
    if (selectedIdx >= 0 && selectedIdx < displays.length)
      return displays[selectedIdx]
    return null
  }

  readonly property string selectedName: selectedDisplay ? selectedDisplay.name : ""
  readonly property bool selectedHasBacklight: selectedName in backlightMap
  readonly property string selectedDevice: selectedHasBacklight ? backlightMap[selectedName] : ""
  readonly property real selectedScale: selectedDisplay ? selectedDisplay.scale : 1

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
    root.refreshDisplays()
    root.detectBacklights()
    root.applyAnchor()
    focusTimer.start()
  }

  function close() {
    root.opened = false
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function refreshDisplays() {
    monitorsProc.exec(["sh", "-c", "hyprctl monitors -j"])
  }

  function detectBacklights() {
    backlightProc.exec(["sh", "-c",
      "for dev in /sys/class/backlight/*/; do " +
      "name=$(basename \"$dev\"); " +
      "target=$(readlink -f \"${dev}device\" 2>/dev/null); " +
      "connector=$(echo \"$target\" | grep -oP 'card\\d+-\\K[A-Za-z0-9-]+$'); " +
      "[ -n \"$connector\" ] && echo \"$connector $name\"; " +
      "done"])
  }

  function applyScale(scale) {
    if (!selectedDisplay) return
    const m = selectedDisplay
    const rule = '{ output = "' + m.name + '", mode = "' + m.width + 'x' + m.height + '@' + m.refresh + '", position = "' + m.x + 'x' + m.y + '", scale = ' + scale + ' }'
    const cmd = "hyprctl eval 'hl.monitor(" + rule + ")'"
    scaleProc.exec(["sh", "-c", cmd])
    persistSettings()
  }

  function applyMode(mode) {
    root.currentMode = mode
    if (mode === "extend") {
      modeProc.exec(["sh", "-c", "$HOME/.config/kmdot/quickshell/scripts/display-mode.sh extend"])
    } else if (mode === "mirror") {
      const primary = displays.length > 0 ? displays[0].name : "eDP-1"
      modeProc.exec(["sh", "-c", "$HOME/.config/kmdot/quickshell/scripts/display-mode.sh mirror " + primary])
    } else if (mode === "external") {
      modeProc.exec(["sh", "-c", "$HOME/.config/kmdot/quickshell/scripts/display-mode.sh external"])
    }
    persistSettings()
  }

  property bool persistInFlight: false
  property bool persistDirty: false

  function persistSettings() {
    if (persistInFlight) { persistDirty = true; return }
    _doPersist()
  }

  function _doPersist() {
    const lines = ["return {"]
    for (let i = 0; i < displays.length; i++) {
      const m = displays[i]
      const isExternal = !(m.name in backlightMap)
      const scale = (m.name === selectedName) ? selectedScale : m.scale
      const disabled = (currentMode === "external" && isExternal) ? "true" : "false"
      const mirrorTarget = (currentMode === "mirror" && isExternal && displays.length > 0) ? displays[0].name : ""
      let rule = "  { output = \"" + m.name + "\", mode = \"" + m.width + "x" + m.height + "@" + m.refresh + "\", position = \"" + m.x + "x" + m.y + "\", scale = " + scale
      if (disabled === "true") rule += ", disabled = true"
      if (mirrorTarget) rule += ", mirror = \"" + mirrorTarget + "\""
      rule += " }"
      if (i < displays.length - 1) rule += ","
      lines.push(rule)
    }
    lines.push("}")
    const luaContent = lines.join("\n")
    const tmpFile = "~/.config/kmdot/display-settings.lua.tmp"
    const targetFile = "~/.config/kmdot/display-settings.lua"
    const linkFile = "~/.config/hypr/display-settings.lua"
    const safe = luaContent.replace(/\\/g, "\\\\").replace(/'/g, "'\\''")
    persistInFlight = true
    persistProc.exec(["sh", "-c",
      "mkdir -p ~/.config/kmdot && " +
      "echo '" + safe + "' > " + tmpFile + " && " +
      "mv " + tmpFile + " " + targetFile + " && " +
      "ln -sf " + targetFile + " " + linkFile])
  }

  Component.onCompleted: {
    detectBacklights()
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
    interval: 5000
    repeat: true
    running: root.opened
    onTriggered: root.refreshDisplays()
  }

  Process {
    id: monitorsProc
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const arr = JSON.parse(this.text)
          const result = []
          for (let i = 0; i < arr.length; i++) {
            const m = arr[i]
            result.push({
              name: m.name,
              width: m.width,
              height: m.height,
              refresh: m.refreshRate ? Math.round(m.refreshRate) : 60,
              x: m.x,
              y: m.y,
              scale: m.scale || 1,
              focused: m.focused || false
            })
          }
          root.displays = result
          if (root.selectedIdx >= result.length) root.selectedIdx = 0
        } catch (e) {}
      }
    }
  }

  Process {
    id: backlightProc
    stdout: StdioCollector {
      onStreamFinished: {
        const map = {}
        const lines = this.text.trim().split("\n")
        for (let i = 0; i < lines.length; i++) {
          const parts = lines[i].split(" ")
          if (parts.length >= 2) {
            map[parts[0]] = parts[1]
          }
        }
        root.backlightMap = map
      }
    }
  }

  Process {
    id: scaleProc
    stdout: StdioCollector {
      onStreamFinished: {
        root.refreshDisplays()
      }
    }
  }

  Process {
    id: modeProc
    stdout: StdioCollector {
      onStreamFinished: {
        root.refreshDisplays()
      }
    }
  }

  Process {
    id: persistProc
    onExited: function(exitCode) {
      persistInFlight = false
      if (exitCode !== 0) console.warn("display-settings persist failed:", exitCode)
      if (persistDirty) { persistDirty = false; _doPersist() }
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

  // Brightness processes (per selected display)
  property int brightnessCur: 0
  property int brightnessMax: 1
  property bool _applyingBrightness: false
  property int _pendingBrightness: -1

  readonly property int brightnessPercent: brightnessMax > 0 ? Math.round(brightnessCur * 100 / brightnessMax) : 0

  function pollBrightness() {
    if (root.selectedDevice) {
      brightnessGetProc.exec(["sh", "-c", "brightnessctl --device " + root.selectedDevice + " get"])
    }
  }

  function applyBrightness(target) {
    if (!root.selectedDevice) return
    const min = Math.round(brightnessMax * 5 / 100)
    const t = Math.max(min, Math.min(brightnessMax, target))
    brightnessCur = t
    if (_applyingBrightness) {
      _pendingBrightness = t
      return
    }
    _applyingBrightness = true
    _pendingBrightness = -1
    brightnessSetProc.exec(["sh", "-c", "brightnessctl --device " + root.selectedDevice + " set " + t])
  }

  onSelectedDeviceChanged: {
    if (selectedDevice) {
      brightnessMaxProc.exec(["sh", "-c", "brightnessctl --device " + selectedDevice + " max"])
      pollBrightness()
    }
  }

  Timer {
    interval: 500
    repeat: true
    running: root.opened && root.selectedHasBacklight
    onTriggered: root.pollBrightness()
  }

  Process {
    id: brightnessGetProc
    stdout: StdioCollector {
      onStreamFinished: {
        const v = parseInt(this.text.replace(/[^0-9]/g, "")) || 0
        if (!root._applyingBrightness) root.brightnessCur = v
      }
    }
  }

  Process {
    id: brightnessMaxProc
    stdout: StdioCollector {
      onStreamFinished: root.brightnessMax = parseInt(this.text.replace(/[^0-9]/g, "")) || 1
    }
  }

  Process {
    id: brightnessSetProc
    onExited: {
      root._applyingBrightness = false
      if (root._pendingBrightness >= 0) {
        const t = root._pendingBrightness
        root._pendingBrightness = -1
        root._applyingBrightness = true
        brightnessSetProc.exec(["sh", "-c", "brightnessctl --device " + root.selectedDevice + " set " + t])
      } else {
        root.pollBrightness()
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
              onClicked: root.selectedIdx = index
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
            onChanged: root.applyBrightness(Math.round(v * root.brightnessMax))
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
              onClicked: root.applyScale(modelData)
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
            onClicked: root.applyMode("extend")
          }

          PillButton {
            width: (body.width - 16) / 3
            height: 30
            filled: true
            active: root.currentMode === "mirror"
            text: "Mirror"
            textSize: 12
            onClicked: root.applyMode("mirror")
          }

          PillButton {
            width: (body.width - 16) / 3
            height: 30
            filled: true
            active: root.currentMode === "external"
            text: "External"
            textSize: 12
            onClicked: root.applyMode("external")
          }
        }
      }
    }
  }
}
