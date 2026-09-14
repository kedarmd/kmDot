import QtQuick
import Quickshell
import Quickshell.Io
import qs
import "../components"
import "../components/serverstatus.js" as ServerStatus

PopupBase {
  id: root
  sockName: "kmdot-server"
  cardWidth: 360

  property string mode: "off"
  property string inhibitor: "inactive"
  property string tailscale: "inactive"
  property string tailscaleIp: ""
  property string jellyfin: "inactive"
  property string busyAction: ""
  property string errorText: ""
  readonly property bool busy: root.busyAction !== ""

  readonly property bool on: root.mode === "on"

  function applyStatus(text) {
    const s = ServerStatus.parseServerStatus(text)
    root.mode = s.mode
    root.inhibitor = s.inhibitor
    root.tailscale = s.tailscale
    root.tailscaleIp = s.tailscaleIp
    root.jellyfin = s.jellyfin
  }

  function refresh() {
    statusProc.exec(["sh", "-c", "$HOME/.config/kmdot/quickshell/scripts/server-mode.sh status"])
  }

  function toggleServerMode(noServices) {
    root.errorText = ""
    root.busyAction = noServices ? "mode:nosvc" : "mode"
    const flag = noServices ? " --no-services" : ""
    modeProc.exec(["sh", "-c", "$HOME/.config/kmdot/quickshell/scripts/server-mode.sh " + (root.on ? "off" : "on") + flag])
  }

  function serviceAction(name, action) {
    root.errorText = ""
    root.busyAction = "service:" + name
    serviceProc.exec(["sh", "-c", "$HOME/.config/kmdot/quickshell/scripts/server-mode.sh service " + name + " " + action])
  }

  function refreshItems() {
    root.errorText = ""
    root.refresh()
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
    stderr: StdioCollector {}
    onExited: function(exitCode) {
      root.busyAction = ""
      if (exitCode !== 0)
        root.errorText = String(modeProc.stderr.text).trim() || "Could not change server mode"
      root.refresh()
    }
  }

  Process {
    id: serviceProc
    stderr: StdioCollector {}
    onExited: function(exitCode) {
      root.busyAction = ""
      if (exitCode !== 0)
        root.errorText = String(serviceProc.stderr.text).trim() || "Could not change service state"
      root.refresh()
    }
  }

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
            fillColor: Tokens.primaryContainer
            activeTextColor: Tokens.on_primary_container
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
            fillColor: Tokens.primaryContainer
            activeTextColor: Tokens.on_primary_container
            glyph: root.busyAction === "mode:nosvc" ? "\uf013" : ""
            glyphSize: 12
            text: root.busyAction === "mode:nosvc" ? "Working\u2026" : (root.on ? "Mode Only: Off" : "Mode Only: On")
            textSize: 12
            onClicked: root.toggleServerMode(true)
          }
        }

        Text {
          visible: root.errorText !== ""
          width: parent.width
          text: root.errorText
          color: Colors.error
          font.family: "JetBrainsMono Nerd Font Propo"
          font.pixelSize: 11
          wrapMode: Text.WordWrap
        }

        Rectangle {
          width: parent.width
          height: 1
          color: Tokens.divider
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
            fillColor: Tokens.primaryContainer
            activeTextColor: Tokens.on_primary_container
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
            fillColor: Tokens.primaryContainer
            activeTextColor: Tokens.on_primary_container
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
          color: Tokens.divider
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
          color: Tokens.divider
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
            radius: height / 2
            color: "transparent"
            border.color: Tokens.outlineVariant
            border.width: 1
            Text {
              anchors.centerIn: parent
              text: "\uf021"
              font.family: "JetBrainsMono Nerd Font Propo"
              font.pixelSize: 12
              color: Colors.text_alt
            }
            StateLayer {
              anchors.fill: parent
              radius: parent.radius
              hovered: refreshMouse.containsMouse
              pressed: refreshMouse.pressed
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
