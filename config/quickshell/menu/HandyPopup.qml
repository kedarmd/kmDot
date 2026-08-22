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
  property var models: []
  property var history: []
  property string selectedModel: ""
  property string errorText: ""
  property int busyId: -1
  property string busyAction: ""
  readonly property bool busy: busyAction !== ""
  readonly property string sockPath: {
    const rt = Quickshell.env("XDG_RUNTIME_DIR")
    return (rt ? rt : "/tmp") + "/kmdot-handy.sock"
  }

  function script() { return Quickshell.env("HOME") + "/.config/kmdot/quickshell/scripts/handy-control.mjs" }
  function run(command, args) {
    const proc = command === "history" ? historyProc : controlProc
    proc.exec(["node", script(), command].concat(args || []))
  }
  function open() {
    if (scope && scope.activeLauncher) scope.activeLauncher.closeLauncher()
    if (scope && scope.batteryPopup) scope.batteryPopup.close()
    if (scope && scope.volumePopup) scope.volumePopup.close()
    if (scope && scope.brightnessPopup) scope.brightnessPopup.close()
    if (scope && scope.calendarPopup) scope.calendarPopup.close()
    if (scope && scope.serverModeDropdown) scope.serverModeDropdown.close()
    if (scope && scope.openCodeUsagePopup) scope.openCodeUsagePopup.close()
    opened = true
    pickScreen()
    refresh()
    focusTimer.start()
  }
  function close() { opened = false; busyAction = ""; busyId = -1 }
  function toggle() { opened ? close() : open() }
  function pickScreen() { posProc.exec(["sh", "-c", "hyprctl cursorpos"]) }
  function refresh() {
    errorText = ""
    run("models")
    run("history")
  }
  function fmtTime(epoch) {
    return new Date(epoch * 1000).toLocaleString(undefined, { month: "short", day: "numeric", hour: "numeric", minute: "2-digit" })
  }
  function applyResult(text) {
    try {
      const result = JSON.parse(String(text))
      if (!result.ok) { errorText = result.error || "Handy operation failed"; return }
      if (result.models) { models = result.models; selectedModel = result.selected || "" }
      if (result.history) history = result.history
      if (result.selected) selectedModel = result.selected
      if (result.text !== undefined) refresh()
    } catch (e) { errorText = "Could not parse Handy response" }
  }
  function selectModel(id) { busyAction = "model"; run("select-model", [id]) }
  function retry(row) { busyId = row.id; busyAction = "retry"; run("retry", [String(row.id), selectedModel]) }
  function save(row, text) { busyId = row.id; busyAction = "save"; run("save", [String(row.id), text]) }
  function copy(text) { copyProc.exec(["sh", "-c", "printf '%s' \"$1\" | wl-copy", "kmdot", text]) }

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
    id: controlProc
    stdout: StdioCollector {
      onStreamFinished: {
        root.applyResult(String(this.text))
        root.busyAction = ""
        root.busyId = -1
      }
    }
  }
  Process {
    id: historyProc
    stdout: StdioCollector { onStreamFinished: root.applyResult(String(this.text)) }
  }
  Process { id: copyProc }
  Process {
    id: posProc
    stdout: StdioCollector {
      onStreamFinished: {
        const m = /(-?\d+),\s*(-?\d+)/.exec(String(this.text).trim())
        if (!m) return
        const x = parseInt(m[1], 10), y = parseInt(m[2], 10)
        const screens = Quickshell.screens.values
        for (let i = 0; i < screens.length; i++) {
          const s = screens[i]
          if (x >= s.x && x < s.x + s.width && y >= s.y && y < s.y + s.height) { root.screen = s; return }
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
      width: 500
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
          width: parent.width; height: 34
          Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "\uf130"; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 23; color: Colors.primary }
          Text { anchors.left: parent.left; anchors.leftMargin: 34; anchors.verticalCenter: parent.verticalCenter; text: "Handy"; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 16; font.weight: Font.DemiBold; color: Colors.text }
          Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: root.busy ? "Working" : (root.tab === 0 ? "Models" : "History"); font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 12; color: Colors.muted }
        }

        Row {
          width: parent.width; spacing: 8
          PillButton { width: (parent.width - 8) / 2; text: "Models"; active: root.tab === 0; onClicked: root.tab = 0 }
          PillButton { width: (parent.width - 8) / 2; text: "History"; active: root.tab === 1; onClicked: root.tab = 1 }
        }
        Text { visible: root.errorText !== ""; width: parent.width; text: root.errorText; color: Colors.error; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 12; wrapMode: Text.WordWrap }

        ListView {
          id: modelList
          visible: root.tab === 0
          width: parent.width
          height: Math.min(330, Math.max(42, contentHeight))
          spacing: 6
          clip: true
          interactive: contentHeight > height
          model: root.models
          delegate: Rectangle {
            required property var modelData
            width: modelList.width - 8; height: 52; radius: 8
            color: modelData.id === root.selectedModel ? Tokens.primaryContainer : Tokens.surfaceContainerHighest
            Text { anchors.left: parent.left; anchors.leftMargin: 12; anchors.right: check.left; anchors.top: parent.top; anchors.topMargin: 8; text: modelData.name; color: modelData.id === root.selectedModel ? Tokens.on_primary_container : Colors.text; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 12; font.weight: modelData.id === root.selectedModel ? Font.DemiBold : Font.Normal; elide: Text.ElideRight }
            Text { anchors.left: parent.left; anchors.leftMargin: 12; anchors.right: check.left; anchors.bottom: parent.bottom; anchors.bottomMargin: 7; text: modelData.engine; color: modelData.id === root.selectedModel ? Tokens.on_primary_container : Colors.muted; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 10; elide: Text.ElideRight }
            Text { id: check; anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; text: modelData.id === root.selectedModel ? "\uf00c" : ""; color: Tokens.on_primary_container; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 14 }
            MouseArea { anchors.fill: parent; enabled: !root.busy; onClicked: root.selectModel(modelData.id) }
          }
        }

        ListView {
          id: historyList
          visible: root.tab === 1
          width: parent.width
          height: Math.min(440, Math.max(70, contentHeight))
          spacing: 8
          clip: true
          interactive: contentHeight > height
          model: root.history
          delegate: Rectangle {
            id: historyRow
            required property var modelData
            width: historyList.width - 8; height: editor.implicitHeight + 58; radius: 8
            color: Tokens.surfaceContainerHighest
            Text { anchors.left: parent.left; anchors.leftMargin: 10; anchors.top: parent.top; anchors.topMargin: 7; text: modelData.title; color: Colors.text_alt; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 10; elide: Text.ElideRight; width: parent.width - 20 }
            TextEdit {
              id: editor
              anchors.left: parent.left; anchors.leftMargin: 10; anchors.right: parent.right; anchors.rightMargin: 10; anchors.top: parent.top; anchors.topMargin: 25
              width: parent.width - 20; height: Math.max(36, implicitHeight); text: modelData.text; color: Colors.text; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 12; wrapMode: TextEdit.Wrap; selectByMouse: true; persistentSelection: true
              readOnly: root.busy && root.busyId !== modelData.id
            }
            Row {
              anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.bottomMargin: 7; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 8
              Text { anchors.verticalCenter: parent.verticalCenter; text: root.fmtTime(modelData.timestamp); color: Colors.muted; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 10; width: 105; elide: Text.ElideRight }
              PillButton { width: 62; height: 24; text: "Save"; glyph: "\uf0c7"; glyphSize: 10; textSize: 10; enabled: !root.busy; onClicked: root.save(modelData, editor.text) }
              PillButton { width: 66; height: 24; text: "Copy"; glyph: "\uf0c5"; glyphSize: 10; textSize: 10; enabled: !root.busy; onClicked: root.copy(editor.text) }
              PillButton { width: 84; height: 24; text: root.busyId === modelData.id && root.busyAction === "retry" ? "Retrying" : (modelData.audioAvailable ? "Retry" : "No audio"); glyph: modelData.audioAvailable ? "\uf2f1" : "\uf071"; glyphSize: 10; textSize: 10; enabled: !root.busy && modelData.audioAvailable; onClicked: root.retry(modelData) }
            }
          }
        }

        Item {
          width: parent.width; height: 24
          Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: root.busy ? "Updating Handy…" : (root.tab === 0 ? root.models.length + " installed model(s)" : root.history.length + " recent recording(s)"); color: Colors.muted; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 10 }
          PillButton { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: 72; height: 24; text: "Refresh"; glyph: "\uf021"; glyphSize: 10; textSize: 10; enabled: !root.busy; onClicked: root.refresh() }
        }
      }
    }
  }
}
