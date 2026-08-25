import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs

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

  anchors { top: true; bottom: true; left: true; right: true }

  property bool opened: false
  onOpenedChanged: root.openedChange()
  property var scope: null
  property string sockName: "kmdot-connection"
  property bool socketEnabled: true
  property string title: "Connections"
  property real cardWidth: 360
  property bool escapeCloses: false
  default property alias content: body.data

  readonly property string sockPath: {
    const rt = Quickshell.env("XDG_RUNTIME_DIR")
    return (rt ? rt : "/tmp") + "/" + root.sockName + ".sock"
  }

  function pickScreen() { posProc.exec(["sh", "-c", "hyprctl cursorpos"]) }

  function open() {
    if (root.scope && root.scope.activeLauncher) root.scope.activeLauncher.closeLauncher()
    if (root.scope && root.scope.batteryPopup) root.scope.batteryPopup.close()
    if (root.scope && root.scope.volumePopup) root.scope.volumePopup.close()
    if (root.scope && root.scope.brightnessPopup) root.scope.brightnessPopup.close()
    if (root.scope && root.scope.calendarPopup) root.scope.calendarPopup.close()
    if (root.scope && root.scope.serverModeDropdown) root.scope.serverModeDropdown.close()
    if (root.scope && root.scope.wifiDropdown && root.scope.wifiDropdown !== root) root.scope.wifiDropdown.close()
    if (root.scope && root.scope.bluetoothDropdown && root.scope.bluetoothDropdown !== root) root.scope.bluetoothDropdown.close()
    if (root.scope && root.scope.wifiAddPopup && root.scope.wifiAddPopup !== root) root.scope.wifiAddPopup.close()
    if (root.scope && root.scope.bluetoothAddPopup && root.scope.bluetoothAddPopup !== root) root.scope.bluetoothAddPopup.close()
    if (root.scope && root.scope.confirmPopup && root.scope.confirmPopup !== root) root.scope.confirmPopup.close()
    root.opened = true
    root.pickScreen()
    focusTimer.start()
    root.refreshItems()
  }

  function close() { root.opened = false }
  function toggle() { if (root.opened) root.close(); else root.open() }
  function refreshItems() {}
  function openedChange() {}

  SocketServer {
    active: root.socketEnabled
    path: root.sockPath
    handler: Socket {
      onConnectedChanged: if (connected) root.toggle()
    }
  }

  Timer {
    id: focusTimer
    interval: 60
    repeat: true
    onTriggered: {
      if (!root.opened) { focusTimer.stop(); return }
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
        const x = parseInt(m[1], 10)
        const y = parseInt(m[2], 10)
        for (const s of Quickshell.screens.values) {
          if (x >= s.x && x < s.x + s.width && y >= s.y && y < s.y + s.height) {
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
    Keys.onEscapePressed: if (root.escapeCloses) root.close()

    MouseArea {
      anchors.fill: parent
      onClicked: root.close()
    }

    Rectangle {
      id: card
      width: root.cardWidth
      height: body.implicitHeight + 32
      radius: 20
      color: Tokens.surfaceContainerLow
      anchors { top: parent.top; topMargin: 48; right: parent.right; rightMargin: 10 }

      MouseArea { anchors.fill: parent }

      Column {
        id: body
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 16 }
        spacing: 12
      }
    }
  }
}
