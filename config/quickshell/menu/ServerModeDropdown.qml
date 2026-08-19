import QtQuick
import Quickshell
import Quickshell.Io
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
  property real cardX: 0

  property string mode: "off"
  property string inhibitor: "inactive"
  property string tailscale: "inactive"
  property string tailscaleIp: ""
  property string jellyfin: "inactive"
  property string busyAction: ""
  readonly property bool busy: root.busyAction !== ""

  readonly property bool on: root.mode === "on"

  readonly property string sockPath: {
    const rt = Quickshell.env("XDG_RUNTIME_DIR")
    return (rt ? rt : "/tmp") + "/kmdot-server.sock"
  }

  function applyStatus(text) {
    for (const line of String(text).split("\n")) {
      const ln = line.trim()
      if (!ln) continue
      const i = ln.indexOf("=")
      if (i < 0) continue
      const k = ln.slice(0, i)
      const v = ln.slice(i + 1)
      if (k === "mode") root.mode = v
      else if (k === "inhibitor") root.inhibitor = v
      else if (k === "tailscale") root.tailscale = v
      else if (k === "tailscale_ip") root.tailscaleIp = v
      else if (k === "jellyfin") root.jellyfin = v
    }
  }

  function refresh() {
    statusProc.exec(["sh", "-c", "$HOME/.config/kmdot/quickshell/scripts/server-mode.sh status"])
  }

  function toggleServerMode(noServices) {
    root.busyAction = noServices ? "mode:nosvc" : "mode"
    const flag = noServices ? " --no-services" : ""
    modeProc.exec(["sh", "-c", "$HOME/.config/kmdot/quickshell/scripts/server-mode.sh " + (root.on ? "off" : "on") + flag])
  }

  function serviceAction(name, action) {
    root.busyAction = "service:" + name
    serviceProc.exec(["sh", "-c", "$HOME/.config/kmdot/quickshell/scripts/server-mode.sh service " + name + " " + action])
  }

  function pickScreen() {
    posProc.exec(["sh", "-c", "hyprctl cursorpos"])
  }

  function open() {
    if (root.scope && root.scope.activeLauncher) root.scope.activeLauncher.closeLauncher()
    if (root.scope && root.scope.batteryPopup && root.scope.batteryPopup !== root) root.scope.batteryPopup.close()
    if (root.scope && root.scope.volumePopup && root.scope.volumePopup !== root) root.scope.volumePopup.close()
    if (root.scope && root.scope.brightnessPopup && root.scope.brightnessPopup !== root) root.scope.brightnessPopup.close()
    if (root.scope && root.scope.calendarPopup) root.scope.calendarPopup.close()
    root.opened = true
    root.refresh()
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
    onTriggered: root.refresh()
  }

  Process {
    id: statusProc
    stdout: StdioCollector {
      onStreamFinished: root.applyStatus(String(this.text))
    }
  }

  Process {
    id: modeProc
    onExited: {
      root.busyAction = ""
      root.refresh()
    }
  }

  Process {
    id: serviceProc
    onExited: {
      root.busyAction = ""
      root.refresh()
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
      width: 360
      height: body.implicitHeight + 32
      radius: 12
      color: Colors.surface
      border.color: Colors.border
      border.width: 1

      anchors {
        top: parent.top
        topMargin: 48
      }
      x: {
        const w = card.width
        const s = root.screen
        const sX = s ? s.x : 0
        const cx = root.cardX > 0 ? (root.cardX - sX) : parent.width / 2
        return Math.max(10, Math.min(parent.width - w - 10, cx - w / 2))
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
        spacing: 10

        Item {
          width: parent.width
          height: 34

          Text {
            id: hdrGlyph
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "\uf233"
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 24
            color: root.on ? Colors.success : Colors.text_alt
          }

          Text {
            id: hdrTitle
            anchors.left: hdrGlyph.right
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: "Server mode"
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 16
            font.weight: Font.DemiBold
            color: Colors.text
          }

          Text {
            id: hdrStatus
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.on ? "On" : "Off"
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 14
            font.weight: Font.DemiBold
            color: root.on ? Colors.success : Colors.muted
          }
        }

        Row {
          width: parent.width
          spacing: 8

          PillButton {
            width: (parent.width - 8) / 2
            height: 32
            active: root.on
            enabled: !root.busy
            glyph: root.busyAction === "mode" ? "\uf013" : (root.on ? "\uf011" : "\uf233")
            glyphSize: 12
            text: root.busyAction === "mode" ? "Working\u2026" : (root.on ? "Turn Off" : "Turn On")
            textSize: 12
            onClicked: root.toggleServerMode(false)
          }

          PillButton {
            width: (parent.width - 8) / 2
            height: 32
            active: root.on
            enabled: !root.busy
            glyph: root.busyAction === "mode:nosvc" ? "\uf013" : ""
            glyphSize: 12
            text: root.busyAction === "mode:nosvc" ? "Working\u2026" : (root.on ? "Mode Only: Off" : "Mode Only: On")
            textSize: 12
            onClicked: root.toggleServerMode(true)
          }
        }

        Rectangle {
          width: parent.width
          height: 1
          color: Colors.border
        }

        Text {
          width: parent.width
          text: "Services"
          font.family: "JetBrainsMono Nerd Font Propo"
          font.pixelSize: 12
          color: Colors.muted
        }

        Row {
          width: parent.width
          height: 34
          spacing: 10

          Text {
            anchors.verticalCenter: parent.verticalCenter
            width: 18
            horizontalAlignment: Text.AlignHCenter
            text: "\uEF09"
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 15
            color: root.tailscale === "active" ? Colors.primary : Colors.muted
          }

          Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 64 - 18 - 20
            spacing: 2

            Text {
              width: parent.width
              text: "Tailscale"
              font.family: "JetBrainsMono Nerd Font Propo"
              font.pixelSize: 12
              font.weight: Font.DemiBold
              color: Colors.text
            }

            Text {
              width: parent.width
              text: root.tailscale === "active"
                ? (root.tailscaleIp ? root.tailscaleIp + " \u00b7 Running" : "Running")
                : "Stopped"
              font.family: "JetBrainsMono Nerd Font Propo"
              font.pixelSize: 11
              color: root.tailscale === "active" ? Colors.success : Colors.warning
              elide: Text.ElideMiddle
            }
          }

          PillButton {
            anchors.verticalCenter: parent.verticalCenter
            width: 64
            enabled: !root.busy
            active: root.tailscale === "active"
            glyph: root.busyAction === "service:tailscale" ? "\uf013" : ""
            glyphSize: 11
            text: root.tailscale === "active" ? "Stop" : "Start"
            textSize: 11
            onClicked: root.serviceAction("tailscale", root.tailscale === "active" ? "stop" : "start")
          }
        }

        Row {
          width: parent.width
          height: 34
          spacing: 10

          Text {
            anchors.verticalCenter: parent.verticalCenter
            width: 18
            horizontalAlignment: Text.AlignHCenter
            text: "\uf008"
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 15
            color: root.jellyfin === "active" ? Colors.primary : Colors.muted
          }

          Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 64 - 18 - 20
            spacing: 2

            Text {
              width: parent.width
              text: "Jellyfin"
              font.family: "JetBrainsMono Nerd Font Propo"
              font.pixelSize: 12
              font.weight: Font.DemiBold
              color: Colors.text
            }

            Text {
              width: parent.width
              text: root.jellyfin === "active" ? "Running" : "Stopped"
              font.family: "JetBrainsMono Nerd Font Propo"
              font.pixelSize: 11
              color: root.jellyfin === "active" ? Colors.success : Colors.warning
            }
          }

          PillButton {
            anchors.verticalCenter: parent.verticalCenter
            width: 64
            enabled: !root.busy
            active: root.jellyfin === "active"
            glyph: root.busyAction === "service:jellyfin" ? "\uf013" : ""
            glyphSize: 11
            text: root.jellyfin === "active" ? "Stop" : "Start"
            textSize: 11
            onClicked: root.serviceAction("jellyfin", root.jellyfin === "active" ? "stop" : "start")
          }
        }

        Rectangle {
          width: parent.width
          height: 1
          color: Colors.border
        }

        Text {
          width: parent.width
          text: "Battery"
          font.family: "JetBrainsMono Nerd Font Propo"
          font.pixelSize: 12
          color: Colors.muted
        }

        Text {
          width: parent.width
          text: root.on
            ? "Background drainers suspended: docker, containerd, Handy, blueman, kmdot-music, uvicorn. Screen behaves per the normal hypridle config."
            : "On enter, docker, containerd, Handy, blueman, kmdot-music and uvicorn are suspended. Edit ~/.config/kmdot/server-mode.conf to change."
          font.family: "JetBrainsMono Nerd Font Propo"
          font.pixelSize: 11
          color: Colors.muted
          wrapMode: Text.WordWrap
          lineHeight: 1.2
        }

        Rectangle {
          width: parent.width
          height: 1
          color: Colors.border
        }

        Item {
          width: parent.width
          height: 24

          Text {
            id: sleepText
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: (root.inhibitor === "active" ? "\uf023" : "\uf09c") + " Sleep " + (root.inhibitor === "active" ? "blocked" : "allowed")
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 10
            color: root.inhibitor === "active" ? Colors.success : Colors.muted
          }

          Text {
            id: busyText
            anchors.right: refreshBtn.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            visible: root.busy
            text: "\uf013"
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 12
            color: Colors.primary
          }

          Rectangle {
            id: refreshBtn
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 56
            height: 22
            radius: 8
            color: refreshMouse.containsMouse ? Colors.surface_alt : Colors.border
            Text {
              anchors.centerIn: parent
              text: "\uf021"
              font.family: "JetBrainsMono Nerd Font Propo"
              font.pixelSize: 12
              color: Colors.text
            }
            MouseArea {
              id: refreshMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.refresh()
            }
          }
        }
      }
    }
  }
}