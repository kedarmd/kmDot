import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import "../components"
import "../components/popuppos.js" as Pos

// Wallpaper switcher (option B, WP-2 rev 2): 3-column grid of the active
// theme's wallpapers. Arrows move selection only; Enter applies via
// set_wallpaper.sh; Esc closes. No live preview, no revert logic.
// Standalone (not a LauncherBase subclass): LauncherBase owns a vertical
// ListView, while this card needs a GridView. Chrome values (card 640x480,
// radius 32, footer 56, type scale) mirror LauncherBase exactly.
Item {
  id: root

  property string sockName: "kmdot-wallpaper"
  property var scope: null
  property bool opened: false
  property bool presentationVisible: false
  property var pool: []
  property int selectedIndex: 0
  property bool loading: false
  property string themeName: ""
  readonly property int columns: 3
  readonly property int resultCount: root.pool.length
  readonly property var selectedItem: root.pool.length > 0
    && root.selectedIndex >= 0 && root.selectedIndex < root.pool.length
    ? root.pool[root.selectedIndex] : null

  readonly property string sockPath: {
    const rt = Quickshell.env("XDG_RUNTIME_DIR")
    return (rt ? rt : "/tmp") + "/" + root.sockName + ".sock"
  }

  function themeLabel(name) {
    if (name === "tokyonight") return "TokyoNight · Night"
    if (name === "catppuccin") return "Catppuccin · Mocha"
    if (name === "everforest") return "Everforest · Dark Hard"
    if (name === "onedark") return "One Dark"
    if (name === "nord") return "Nord"
    return name
  }

  function subtitle() {
    if (root.loading) return "Loading…"
    if (!root.themeName) return ""
    const n = root.pool.length
    return root.themeLabel(root.themeName) + " — " + n + (n === 1 ? " wallpaper" : " wallpapers")
  }

  function refreshItems() {
    root.loading = true
    root.pool = []
    root.themeName = ""
    listProc.exec(["sh", "-c", "$HOME/.config/kmdot/quickshell/scripts/list-wallpapers.sh"])
  }

  function readRow(line) {
    const fields = String(line).replace(/[\r\n]+$/, "").split("\t")
    if (fields.length < 5 || fields[2] === "") return
    root.themeName = fields[4]
    const dims = fields[3] !== "" ? fields[3].replace("x", " × ") : ""
    root.pool = root.pool.concat([{
      active: fields[0] === "ACTIVE",
      label: fields[1],
      path: fields[2],
      dims: dims,
      meta: fields[1].replace(/^[a-z]+-0*/, "") + (dims !== "" ? " · " + dims : "")
    }])
  }

  function openLauncher() {
    root.selectedIndex = 0
    root.refreshItems()
    if (root.scope && root.scope.closeAllExcept) root.scope.closeAllExcept(root)
    if (root.scope) root.scope.activeLauncher = root
    root.opened = true
  }

  function closeLauncher() {
    if (!root.opened) return
    root.opened = false
    if (root.scope && root.scope.activeLauncher === root) root.scope.activeLauncher = null
  }

  function toggleLauncher() {
    if (root.opened) root.closeLauncher()
    else root.openLauncher()
  }

  function move(delta) {
    if (root.pool.length === 0) return
    root.selectedIndex = Math.min(root.pool.length - 1, Math.max(0, root.selectedIndex + delta))
    grid.positionViewAtIndex(root.selectedIndex, GridView.Contain)
  }

  function activate() {
    if (root.selectedIndex < 0 || root.selectedIndex >= root.pool.length) return
    const item = root.pool[root.selectedIndex]
    root.closeLauncher()
    root.runCommand("$HOME/.config/kmdot/hyprland/scripts/set_wallpaper.sh '" + item.path.replace(/'/g, "'\\''") + "'")
  }

  function activateAt(i) {
    root.selectedIndex = i
    root.activate()
  }

  function runCommand(cmd) {
    cmdProc.exec(["sh", "-c", cmd])
  }

  onOpenedChanged: {
    if (root.opened) {
      closePresentationTimer.stop()
      root.presentationVisible = true
      focusTimer.start()
    } else {
      closePresentationTimer.restart()
    }
  }

  Process {
    id: cmdProc
  }

  Process {
    id: listProc
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function(data) {
        const line = String(data).replace(/[\r\n]+$/, "")
        if (line !== "") root.readRow(line)
      }
    }
    onExited: {
      root.loading = false
      const activeIndex = root.pool.findIndex(item => item.active)
      root.selectedIndex = activeIndex >= 0 ? activeIndex : 0
      grid.positionViewAtIndex(root.selectedIndex, GridView.Contain)
    }
  }

  Timer {
    id: closePresentationTimer
    interval: Tokens.motionStandard
    onTriggered: root.presentationVisible = false
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
      navKeys.forceActiveFocus()
      if (navKeys.activeFocus) focusTimer.stop()
    }
  }

  SocketServer {
    active: true
    path: root.sockPath
    handler: Socket {
      onConnectedChanged: {
        if (connected) root.toggleLauncher()
      }
    }
  }

  PanelWindow {
    id: launcherWin
    visible: root.presentationVisible
    screen: Pos.primaryScreen(Quickshell.screens)
    color: Qt.rgba(0, 0, 0, 0)
    focusable: true

    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: Qt.rgba(0, 0, 0, root.opened ? 0.4 : 0)
      Behavior on color {
        ColorAnimation { duration: Tokens.motionStandard; easing.type: Easing.OutCubic }
      }
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.closeLauncher()
    }

    Rectangle {
      id: card
      width: Math.min(640, parent.width - 32)
      height: Math.min(480, parent.height - 32)
      anchors.centerIn: parent
      radius: 32
      color: Colors.surface
      border.width: 1
      border.color: Colors.border
      opacity: root.opened ? 1 : 0
      scale: root.opened ? 1 : 0.96

      Behavior on opacity {
        NumberAnimation { duration: Tokens.motionStandard; easing.type: Easing.OutCubic }
      }
      Behavior on scale {
        NumberAnimation { duration: Tokens.motionEmphasized; easing.type: Easing.OutBack }
      }

      MouseArea {
        anchors.fill: parent
      }

      Item {
        id: navKeys
        anchors.fill: parent
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Left) { root.move(-1); event.accepted = true }
          else if (event.key === Qt.Key_Right) { root.move(1); event.accepted = true }
          else if (event.key === Qt.Key_Up) { root.move(-root.columns); event.accepted = true }
          else if (event.key === Qt.Key_Down) { root.move(root.columns); event.accepted = true }
          else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.activate(); event.accepted = true }
          else if (event.key === Qt.Key_Escape) { root.closeLauncher(); event.accepted = true }
        }
      }

      Text {
        anchors { top: parent.top; left: parent.left; topMargin: 20; leftMargin: 24 }
        text: "Wallpapers"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 20
        font.weight: Font.DemiBold
        color: Colors.text
      }

      Text {
        anchors { top: parent.top; left: parent.left; topMargin: 52; leftMargin: 24 }
        text: root.subtitle()
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 12
        color: Colors.text_alt
      }

      R1Icon {
        width: 24
        height: 24
        anchors { right: parent.right; top: parent.top; rightMargin: 32; topMargin: 26 }
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
          onClicked: root.closeLauncher()
        }
      }

      GridView {
        id: grid
        anchors {
          top: parent.top
          left: parent.left
          right: parent.right
          bottom: footer.top
          leftMargin: 24
          rightMargin: 24
          topMargin: 96
          bottomMargin: 8
        }
        visible: !root.loading && root.pool.length > 0
        clip: true
        model: root.pool
        cellWidth: 197
        cellHeight: 160
        flow: GridView.FlowLeftToRight

        delegate: Item {
          required property var modelData
          required property int index
          width: 197
          height: 160

          Rectangle {
            id: cell
            width: 186
            height: 148
            radius: 16
            color: root.selectedIndex === index ? Colors.primary_container : "transparent"
            border.width: root.selectedIndex === index ? 2 : 1
            border.color: root.selectedIndex === index ? Colors.primary : Tokens.outlineVariant

            // Full-bleed cropped preview masked to the cell radius (16): thumb
            // and cell share one curvature, and cropping (never letterbox)
            // keeps every tile identical regardless of selection state.
            Item {
              id: previewSlot
              anchors { top: parent.top; left: parent.left; right: parent.right }
              height: 105

              Rectangle {
                anchors.fill: parent
                radius: 16
                color: Colors.surface_alt
              }

              Image {
                id: thumbImg
                anchors.fill: parent
                source: modelData.path
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: false
              }

              Rectangle {
                id: previewMask
                anchors.fill: parent
                radius: 16
                visible: false
              }

              MultiEffect {
                anchors.fill: parent
                source: thumbImg
                maskEnabled: true
                maskSource: previewMask
              }

              Rectangle {
                visible: modelData.active
                anchors { top: parent.top; left: parent.left; topMargin: 8; leftMargin: 8 }
                height: 28
                width: activeLabel.implicitWidth + 28
                radius: 14
                color: Colors.surface_highest

                Text {
                  id: activeLabel
                  anchors.centerIn: parent
                  text: "Active"
                  font.family: "JetBrainsMono Nerd Font"
                  font.pixelSize: 12
                  font.weight: Font.Bold
                  color: Colors.text_alt
                }
              }
            }

            Text {
              anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 109; leftMargin: 12; rightMargin: 12 }
              text: modelData.label
              elide: Text.ElideRight
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 12
              font.weight: root.selectedIndex === index ? Font.Bold : Font.Normal
              color: root.selectedIndex === index ? Colors.text : Colors.text_alt
            }

            Text {
              anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 125; leftMargin: 12; rightMargin: 12 }
              text: modelData.meta
              elide: Text.ElideRight
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 12
              color: root.selectedIndex === index ? Colors.text : Colors.muted
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              onEntered: root.selectedIndex = index
              onClicked: root.activateAt(index)
            }
          }
        }
      }

      Column {
        anchors.centerIn: parent
        visible: !root.loading && root.pool.length === 0
        spacing: 12

        R1Icon {
          anchors.horizontalCenter: parent.horizontalCenter
          iconName: "palette"
          font.pixelSize: 24
          color: Tokens.mutedText
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "No wallpapers for this theme"
          font.pixelSize: 14
          font.family: "JetBrainsMono Nerd Font"
          color: Tokens.mutedText
        }
      }

      Rectangle {
        id: footer
        anchors {
          left: parent.left
          right: parent.right
          bottom: parent.bottom
          leftMargin: 1
          rightMargin: 1
          bottomMargin: 1
        }
        height: 56
        radius: 32
        color: Colors.base

        Rectangle {
          anchors {
            top: parent.top
            left: parent.left
            right: parent.right
          }
          height: 28
          color: Colors.base
        }

        Rectangle {
          anchors {
            top: parent.top
            left: parent.left
            right: parent.right
          }
          height: 1
          color: Tokens.divider
        }

        Text {
          anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
            leftMargin: 24
          }
          text: "↑ ↓ ← → select · ⏎ apply"
          font.pixelSize: 12
          font.family: "JetBrainsMono Nerd Font"
          color: Tokens.mutedText
        }

        Text {
          anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
            rightMargin: 24
          }
          text: "esc Close"
          font.pixelSize: 12
          font.family: "JetBrainsMono Nerd Font"
          color: Tokens.mutedText
        }
      }
    }
  }
}
