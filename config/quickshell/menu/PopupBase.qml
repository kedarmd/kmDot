import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
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
  // NOTE: indexed access, not .values — the .values snapshot does not track the
  // model (reads empty while screens is populated), which unmapped overlays
  // while opened stayed true. Same reason for the indexed loop in posProc.
  screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null

  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
  WlrLayershell.exclusionMode: ExclusionMode.Ignore

  anchors { top: true; bottom: true; left: true; right: true }

  property bool opened: false
  onOpenedChanged: root.openedChange()
  property var scope: null
  // anchorItem seam: the bar module sets this to itself right before toggling
  // so the card centers under that module (see applyAnchor). anchorGX is the
  // consumed global center X; sub-popups inherit it by copying it before open().
  property var anchorItem: null
  property real anchorGX: -1
  property string sockName: "kmdot-connection"
  property bool socketEnabled: true
  property string title: "Connections"
  property real cardWidth: 360
  // Card vertical chrome (top+bottom padding) and optional height cap (0 = uncapped).
  // The two height-capped cards override these: Display (600), NotificationCenter (24 + root.height-80).
  property real cardChrome: 32
  property real cardMaxHeight: 0
  property bool escapeCloses: true
  // Focus seam: the item that should hold keyboard focus while open.
  // Subclasses with their own focus owner override it (Calendar's nav Column,
  // WifiAdd's ssidInput); the focus timer below yields to it. Defaults to the
  // base content Item (Escape/backdrop handling).
  property Item focusItem: content
  default property alias content: body.data

  readonly property string sockPath: {
    const rt = Quickshell.env("XDG_RUNTIME_DIR")
    return (rt ? rt : "/tmp") + "/" + root.sockName + ".sock"
  }

  function pickScreen() { posProc.exec(["sh", "-c", "hyprctl cursorpos"]) }

  function applyAnchor() {
    if (root.anchorItem) {
      const gx = Pos.globalCenterX(root.anchorItem)
      root.anchorItem = null
      if (gx >= 0) root.anchorGX = gx
    }
    if (root.anchorGX >= 0) {
      const s = Pos.screenFor(Quickshell.screens, root.anchorGX)
      if (s) root.screen = s
      else root.pickScreen()
    } else {
      root.pickScreen()
    }
  }

  function open() {
    if (root.scope && root.scope.closeAllExcept) root.scope.closeAllExcept(root)
    root.opened = true
    root.applyAnchor()
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
      // Yield to whichever item holds window focus (e.g. a subclass focusItem):
      // only grab when nothing does. Checking content.activeFocus alone is not
      // enough — a focused plain-Item child does not propagate activeFocus up,
      // so the old guard stole focus back every tick (broke Calendar nav).
      const win = content.Window.window
      const holder = win ? win.activeFocusItem : null
      if (holder === root.focusItem) { focusTimer.stop(); return }
      if (!holder) { root.focusItem.forceActiveFocus(); return }
      focusTimer.stop()
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
        for (let i = 0; i < Quickshell.screens.length; i++) {
          const s = Quickshell.screens[i]
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
      height: root.cardMaxHeight > 0 ? Math.min(body.implicitHeight + root.cardChrome, root.cardMaxHeight) : body.implicitHeight + root.cardChrome
      radius: 20
      color: Tokens.surfaceContainerLow
      anchors { top: parent.top; topMargin: 48 }
      x: root.anchorGX >= 0
        ? Pos.cardXFor(root.anchorGX, card.width, root.screen)
        : parent.width - card.width - 10

      MouseArea { anchors.fill: parent }

      Column {
        id: body
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 16 }
        spacing: 12
      }
    }
  }
}
