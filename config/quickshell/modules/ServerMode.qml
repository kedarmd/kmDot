import QtQuick
import Quickshell.Io
import qs
import "../components"

Item {
  id: root
  implicitHeight: 30
  width: Math.max(30, label.implicitWidth + 20)
  property var tooltip: null
  required property var dropdown

  signal activated

  property string mode: "off"
  property real spinAngle: 0

  NumberAnimation on spinAngle {
    from: 0
    to: 360
    duration: 1200
    running: root.busy
    loops: Animation.Infinite
  }

  readonly property bool active: root.mode === "on"
  readonly property bool busy: root.dropdown ? root.dropdown.busy : false
  readonly property string tooltipText: "Server mode: " + (root.active ? "On" : "Off")

  function applyStatus(text) {
    for (const line of String(text).split("\n")) {
      const ln = line.trim()
      if (!ln) continue
      const i = ln.indexOf("=")
      if (i < 0) continue
      const k = ln.slice(0, i)
      const v = ln.slice(i + 1)
      if (k === "mode") root.mode = v
    }
  }

  function refresh() {
    statusProc.exec(["sh", "-c", "$HOME/.config/kmdot/quickshell/scripts/server-mode.sh status"])
  }

  function openDropdown() {
    var cx = 0
    try {
      cx = root.mapToGlobal(root.width / 2, 0).x
    } catch (e) {
      var win = root.Window.window
      if (win) {
        var pos = root.mapToItem(win.contentItem, root.width / 2, 0)
        cx = (win.x || 0) + pos.x
      }
    }
    root.dropdown.cardX = cx
    root.dropdown.open()
  }

  Timer {
    interval: 2000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }
  Component.onCompleted: root.refresh()

  ModulePill {
    id: pill
    anchors.centerIn: parent
    width: Math.max(30, label.implicitWidth + 20)
    height: 30
    active: root.active
    fill: Tokens.successContainer
    hovered: mouse.containsMouse
    pressed: mouse.pressed

    Text {
      id: label
      anchors.centerIn: parent
      text: root.busy ? "\uf013" : "\uf233"
      font.family: "JetBrainsMono Nerd Font Propo"
      font.pixelSize: 14
      color: root.busy ? Tokens.primary : (root.active ? Tokens.on_success_container : Colors.text_alt)
      opacity: root.busy ? 1.0 : (root.active ? 1.0 : 0.4)
      rotation: root.busy ? root.spinAngle : 0
      transformOrigin: Item.Center
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: {
      root.activated()
      if (root.dropdown.opened) {
        root.dropdown.close()
      } else {
        root.openDropdown()
      }
    }
    onEntered: {
      if (root.tooltip) root.tooltip.show(root, root.tooltipText)
    }
    onExited: {
      if (root.tooltip) root.tooltip.hide()
    }
  }

  Process {
    id: statusProc
    stdout: StdioCollector {
      onStreamFinished: root.applyStatus(String(this.text))
    }
  }
}