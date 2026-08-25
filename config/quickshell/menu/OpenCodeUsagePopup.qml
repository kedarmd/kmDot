import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import "../components"

PanelWindow {
  id: root
  visible: opened
  color: Qt.rgba(0, 0, 0, 0)
  focusable: true
  screen: Quickshell.screens.values.length > 0 ? Quickshell.screens.values[0] : null

  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
  WlrLayershell.exclusionMode: ExclusionMode.Ignore

  anchors { top: true; bottom: true; left: true; right: true }

  property bool opened: false
  property var scope: null
  property int tab: 0
  property var report: null
  property string errorText: ""
  readonly property string sockPath: {
    const rt = Quickshell.env("XDG_RUNTIME_DIR")
    return (rt ? rt : "/tmp") + "/kmdot-opencode-usage.sock"
  }

  function open() {
    if (scope && scope.activeLauncher) scope.activeLauncher.closeLauncher()
    if (scope && scope.batteryPopup) scope.batteryPopup.close()
    if (scope && scope.volumePopup) scope.volumePopup.close()
    if (scope && scope.brightnessPopup) scope.brightnessPopup.close()
    if (scope && scope.calendarPopup) scope.calendarPopup.close()
    if (scope && scope.serverModeDropdown) scope.serverModeDropdown.close()
    opened = true
    pickScreen()
    refresh()
    focusTimer.start()
  }

  function close() { opened = false }
  function toggle() { opened ? close() : open() }
  function refresh() {
    if (usageProc.running) return
    usageProc.exec(["sh", "-c", "node \"$HOME/.config/kmdot/quickshell/scripts/opencode-usage.mjs\""])
  }
  function pickScreen() { posProc.exec(["sh", "-c", "hyprctl cursorpos"]) }
  function formatTokens(value) {
    if (value >= 1000000000) return (value / 1000000000).toFixed(1) + "B"
    if (value >= 1000000) return (value / 1000000).toFixed(1) + "M"
    if (value >= 1000) return (value / 1000).toFixed(1) + "K"
    return String(Math.round(value || 0))
  }
  function formatCost(value) { return "$" + Number(value || 0).toFixed(2) }
  function applyReport(text) {
    const trimmed = String(text).trim()
    if (trimmed === "") return
    try {
      const parsed = JSON.parse(trimmed)
      report = parsed.ok ? parsed : null
      errorText = parsed.ok ? "" : (parsed.error || "Could not load usage")
    } catch (e) {
      report = null
      errorText = "Could not parse usage data"
    }
  }

  SocketServer {
    active: true
    path: root.sockPath
    handler: Socket { onConnectedChanged: if (connected) root.toggle() }
  }

  Timer {
    id: focusTimer
    interval: 60
    repeat: true
    onTriggered: {
      if (!root.opened) { stop(); return }
      content.forceActiveFocus()
      if (content.activeFocus) stop()
    }
  }

  Process {
    id: usageProc
    stdout: StdioCollector { onStreamFinished: root.applyReport(String(this.text)) }
  }

  Process {
    id: posProc
    stdout: StdioCollector {
      onStreamFinished: {
        const match = /(-?\d+),\s*(-?\d+)/.exec(String(this.text).trim())
        if (!match) return
        const x = parseInt(match[1], 10), y = parseInt(match[2], 10)
        const screens = Quickshell.screens.values
        for (let i = 0; i < screens.length; i++) {
          const screenData = screens[i]
          if (x >= screenData.x && x < screenData.x + screenData.width
              && y >= screenData.y && y < screenData.y + screenData.height) {
            root.screen = screenData
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

    MouseArea { anchors.fill: parent; onClicked: root.close() }

    Rectangle {
      id: card
      width: 430
      height: body.implicitHeight + 32
      radius: 20
      color: Tokens.surfaceContainerHigh
      anchors { top: parent.top; topMargin: 48; right: parent.right; rightMargin: 10 }
      MouseArea { anchors.fill: parent }

      Column {
        id: body
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 16 }
        spacing: 10

        Item {
          width: parent.width
          height: 34
          Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "\uf121"; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 23; color: Colors.primary }
          Text { anchors.left: parent.left; anchors.leftMargin: 34; anchors.verticalCenter: parent.verticalCenter; text: "OpenCode usage"; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 16; font.weight: Font.DemiBold; color: Colors.text }
          Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: root.report ? "7 days" : "Loading"; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 12; color: Colors.muted }
        }

        Row {
          width: parent.width
          spacing: 8
          PillButton { width: (parent.width - 8) / 2; text: "Daily"; active: root.tab === 0; onClicked: root.tab = 0 }
          PillButton { width: (parent.width - 8) / 2; text: "Models"; active: root.tab === 1; onClicked: root.tab = 1 }
        }

        Text { visible: root.errorText !== ""; width: parent.width; text: root.errorText; color: Colors.error; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 12; wrapMode: Text.WordWrap }
        Text { visible: !root.report && root.errorText === ""; width: parent.width; text: "Loading usage data…"; color: Colors.muted; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 12 }

        Column {
          visible: !!root.report && root.tab === 0
          width: parent.width
          spacing: 8
          Repeater {
            model: root.report ? root.report.days : []
            delegate: Item {
              required property var modelData
              width: parent.width
              height: 38
              readonly property real maximum: {
                let max = 1
                for (const day of (root.report ? root.report.days : [])) max = Math.max(max, day.tokens)
                return max
              }
              Text { anchors.left: parent.left; anchors.verticalCenter: progressTrack.verticalCenter; width: 42; text: modelData.label; color: Colors.text_alt; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 12 }
              Text { anchors.right: parent.right; anchors.top: parent.top; text: root.formatTokens(modelData.tokens) + " · " + root.formatCost(modelData.cost); color: Colors.text; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 12 }
              Rectangle { id: progressTrack; anchors.left: parent.left; anchors.leftMargin: 48; anchors.right: parent.right; anchors.top: parent.top; anchors.topMargin: 22; height: 8; radius: 4; color: Tokens.surfaceContainerHighest
                Rectangle { width: parent.width * modelData.tokens / maximum; height: parent.height; radius: 4; color: Colors.primary }
              }
            }
          }
        }

        ListView {
          id: modelList
          visible: !!root.report && root.tab === 1
          width: parent.width
          height: Math.min(300, contentHeight)
          spacing: 6
          interactive: contentHeight > height
          clip: true
          model: root.report ? root.report.models : []
          delegate: Rectangle {
            required property var modelData
            width: modelList.width - 8
            height: 48
            radius: 8
            color: Tokens.surfaceContainerHighest
            Text { anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.topMargin: 8; anchors.leftMargin: 12; anchors.rightMargin: 12; text: modelData.model; color: Colors.text; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 12; elide: Text.ElideMiddle }
            Text { anchors.left: parent.left; anchors.leftMargin: 12; anchors.bottom: parent.bottom; anchors.bottomMargin: 7; text: root.formatTokens(modelData.tokens) + " tokens"; color: Colors.text_alt; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 11 }
            Text { anchors.right: parent.right; anchors.rightMargin: 12; anchors.bottom: parent.bottom; anchors.bottomMargin: 7; text: root.formatCost(modelData.cost); color: Colors.text_alt; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 11 }
          }
          Rectangle {
            visible: modelList.contentHeight > modelList.height
            width: 4
            radius: 2
            color: Colors.muted
            opacity: 0.6
            z: 2
            anchors.right: parent.right
            anchors.rightMargin: 1
            y: modelList.contentY * (modelList.height - height)
              / Math.max(1, modelList.contentHeight - modelList.height)
            height: Math.max(24, modelList.height * modelList.height / modelList.contentHeight)
          }
        }

        Item {
          width: parent.width
          height: 42
          Column {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            Text { text: "7-day total"; color: Colors.muted; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 11 }
            Text { text: root.report ? root.formatTokens(root.report.total.tokens) + " tokens · " + root.formatCost(root.report.total.cost) : "—"; color: Colors.text; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 14; font.weight: Font.DemiBold }
          }
          PillButton { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: 74; text: "Refresh"; glyph: "\uf021"; enabled: !usageProc.running; onClicked: root.refresh() }
        }
        Text { width: parent.width; text: "Quota unavailable from the OpenCode CLI"; color: Colors.muted; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 10 }
      }
    }
  }
}
