import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import "../components"
import "../components/popuppos.js" as Pos

PanelWindow {
  id: root

  visible: root.presentationVisible
  color: Qt.rgba(0, 0, 0, 0)
  focusable: true

  // NOTE: Pos.primaryScreen (indexed), not .values — the .values snapshot does
  // not track the model (reads empty while screens is populated), which
  // unmapped overlays while opened stayed true. Same reason for the indexed
  // loop in posProc.
  screen: Pos.primaryScreen(Quickshell.screens)

  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
  WlrLayershell.exclusionMode: ExclusionMode.Ignore

  anchors { top: true; bottom: true; left: true; right: true }

  property bool animatePresentation: true
  property bool opened: false
  readonly property bool presentationVisible: presentation.presented
  property SurfacePresentation presentation: SurfacePresentation { opened: root.opened }
  onOpenedChanged: root.openedChange()
  property var scope: null
  // anchorItem seam: the bar module sets this to itself right before toggling
  // so the card opens on that module's screen (see applyAnchor). anchorX is
  // local to that screen; sub-popups may inherit it before opening.
  property var anchorItem: null
  property real anchorX: -1
  property bool anchorGlobal: false
  property string sockName: "kmdot-connection"
  property bool socketEnabled: true
  property string title: "Connections"
  property real cardWidth: 424
  property bool centerCard: false
  // Card vertical chrome (top+bottom padding) and optional height cap (0 = uncapped).
  // Taller panel cards set explicit bounds to match their Penpot frames.
  property real cardChrome: 48
  property real cardMinHeight: 0
  property real cardMaxHeight: 0
  property alias bottomContent: footerSlot.data
  property bool escapeCloses: true
  property bool tabNavigation: false
  // Focus seam: the item that should hold keyboard focus while open.
  // Subclasses with their own focus owner override it (Calendar's nav Column,
  // WifiAdd's ssidInput); the focus timer below yields to it. Defaults to the
  // base content Item (Escape/backdrop handling).
  property Item focusItem: content
  default property alias content: body.data
  function navigateTab(direction) {}

  readonly property string sockPath: {
    const rt = Quickshell.env("XDG_RUNTIME_DIR")
    return (rt ? rt : "/tmp") + "/" + root.sockName + ".sock"
  }

  function pickScreen() { posProc.exec(["sh", "-c", "hyprctl cursorpos"]) }

  function applyAnchor() {
    if (root.anchorItem) {
      root.anchorX = -1
      root.anchorGlobal = false
      const anchor = Pos.anchorForItem(root.anchorItem, Quickshell.screens,
        root.anchorItem.QsWindow.window)
      root.anchorItem = null
      if (anchor) {
        if (anchor.screen) root.screen = anchor.screen
        root.anchorX = anchor.centerX
        root.anchorGlobal = !!anchor.global
      }
    }
    if (root.anchorX < 0 || !root.screen) root.pickScreen()
  }

  function open() {
    if (root.scope && root.scope.closeAllExcept) root.scope.closeAllExcept(root)
    root.applyAnchor()
    root.opened = true
    focusTimer.start()
    root.refreshItems()
  }

  function close() { root.opened = false }
  function toggle() { if (root.opened) root.close(); else root.open() }
  function refreshItems() {}
  function openedChange() {}

  function inheritAnchor(popup) {
    if (!popup) return
    popup.screen = root.screen
    popup.anchorX = root.anchorX
    popup.anchorGlobal = root.anchorGlobal
  }

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
      // Anything else (nothing focused yet, or a lost race that left focus on
      // content): steer back to the declared focus owner and keep polling
      // until it holds.
      root.focusItem.forceActiveFocus()
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
    Keys.onTabPressed: function(event) {
      if (!root.tabNavigation) return
      root.navigateTab(1)
      event.accepted = true
    }
    Keys.onBacktabPressed: function(event) {
      if (!root.tabNavigation) return
      root.navigateTab(-1)
      event.accepted = true
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.close()
    }

    Rectangle {
      id: card
      width: root.cardWidth
      height: Math.min(parent.height - 80, root.cardMaxHeight > 0
        ? Math.min(Math.max(body.implicitHeight + footerSlot.height + (footerSlot.children.length > 0 ? 16 : 0) + root.cardChrome, root.cardMinHeight), root.cardMaxHeight)
        : Math.max(body.implicitHeight + footerSlot.height + (footerSlot.children.length > 0 ? 16 : 0) + root.cardChrome, root.cardMinHeight))
      radius: 32
      color: Colors.surface_high
      border.width: Tokens.surfaceBorderWidth
      border.color: Colors.border
      opacity: root.opened ? 1 : 0

      // Resolve geometry immediately: animating height makes newly mapped
      // panels unroll from the top while their opacity is still fading in.
      Behavior on opacity {
        NumberAnimation { duration: root.animatePresentation ? Tokens.motionStandard : 0; easing.type: Tokens.motionEasing }
      }
      y: root.centerCard ? (parent.height - card.height) / 2 : 64
      x: root.centerCard
        ? (parent.width - card.width) / 2
        : root.anchorX >= 0
        ? Pos.cardXFor(root.anchorX, card.width, root.screen, root.anchorGlobal)
        : parent.width - card.width - 16

      MouseArea { anchors.fill: parent }

      Flickable {
        id: bodyViewport
        anchors {
          top: parent.top
          left: parent.left
          right: parent.right
          bottom: footerSlot.children.length > 0 ? footerSlot.top : parent.bottom
          leftMargin: 24
          rightMargin: 24
          topMargin: 24
          bottomMargin: footerSlot.children.length > 0 ? 16 : 24
        }
        clip: true
        contentWidth: width
        contentHeight: body.implicitHeight
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        Column {
          id: body
          width: bodyViewport.width
          spacing: 16
        }
      }

      Item {
        id: footerSlot
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 24; rightMargin: 24; bottomMargin: 24 }
        height: children.length > 0 ? childrenRect.height : 0
      }

      R1Icon {
        width: 24
        height: 24
        anchors { top: parent.top; right: parent.right; topMargin: 24; rightMargin: 24 }
        glyph: "\uf00d"
        font.family: "JetBrainsMono Nerd Font Propo"
        font.pixelSize: 16
        color: Colors.text_alt
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        MouseArea {
          anchors.fill: parent
          anchors.margins: -8
          cursorShape: Qt.PointingHandCursor
          onClicked: root.close()
        }
      }
    }
  }
}
