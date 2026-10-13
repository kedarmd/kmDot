import QtQuick
import Quickshell
import Quickshell.Io
import qs
import "../components"
import "../components/serverstatus.js" as ServerStatus

PopupBase {
  id: root
  sockName: "kmdot-server"
  cardWidth: 424
  cardMinHeight: root.errorText && root.failedService ? 424 : 576

  property string mode: "off"
  property string inhibitor: "inactive"
  property string tailscale: "inactive"
  property string tailscaleIp: ""
  property string jellyfin: "inactive"
  property string busyAction: ""
  property string errorText: ""
  property string failedService: ""
  property string failedServiceAction: ""
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
    root.failedService = ""
    root.busyAction = noServices ? "mode:nosvc" : "mode"
    const flag = noServices ? " --no-services" : ""
    modeProc.exec(["sh", "-c", "$HOME/.config/kmdot/quickshell/scripts/server-mode.sh " + (root.on ? "off" : "on") + flag])
  }

  function serviceAction(name, action) {
    root.errorText = ""
    root.busyAction = "service:" + name
    root.failedService = name
    root.failedServiceAction = action
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
    visible: !(root.errorText && root.failedService)
    width: parent.width
    height: 528 + (root.errorText ? errorCard.height + 16 : 0)
    Row {
      spacing: 16
      R1Icon { glyph: "\uf233"; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 24; color: Colors.text; anchors.verticalCenter: parent.verticalCenter }
      Text { text: "Server mode"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 24; font.weight: Font.DemiBold; color: Colors.text }
    }
    Text {
      y: 64; width: parent.width - 56
      text: "Keep the laptop available"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16; color: Colors.text
    }
    Text {
      y: 91; width: parent.width - 56
      text: "Sleep " + (root.inhibitor === "active" ? "blocked" : "allowed") + " · Screen follows idle"
      font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: Colors.text_alt
    }
    Rectangle {
      y: 68; anchors.right: parent.right; width: 48; height: 28; radius: 14
      color: root.on ? Colors.primary : Colors.border
      opacity: root.busy ? 0.38 : 1
      Rectangle { x: root.on ? 24 : 4; y: 4; width: 20; height: 20; radius: 10; color: root.on ? Colors.surface : Colors.text_alt }
      MouseArea { anchors.fill: parent; enabled: !root.busy; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleServerMode(true) }
    }
    Row {
      y: 140; width: parent.width; spacing: 8
      PillButton {
        width: 224; height: 40; filled: true; active: true; enabled: !root.busy; textSize: 14
        text: root.busyAction === "mode" ? "Working…" : root.on ? "Turn off + services" : "Turn on + services"
        onClicked: root.toggleServerMode(false)
      }
      PillButton {
        width: parent.width - 232; height: 40; filled: true; inactiveFillColor: Colors.surface_alt; enabled: !root.busy; textSize: 14
        text: root.busyAction === "mode:nosvc" ? "Working…" : "Mode only"
        onClicked: root.toggleServerMode(true)
      }
    }
    Text { y: 212; text: "SERVICES"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: Colors.text_alt }
    Column {
      y: 240; width: parent.width; spacing: 8
      Repeater {
        model: [{name: "Tailscale", service: "tailscale", state: root.tailscale, detail: root.tailscaleIp || "Private network", glyph: "\uf0ac"},
                {name: "Jellyfin", service: "jellyfin", state: root.jellyfin, detail: "Media server", glyph: "\uf04b"}]
        Rectangle {
          required property var modelData
          width: parent.width; height: 72; radius: 16
          color: modelData.state === "active" ? Colors.primary_container : Colors.surface_alt
          R1Icon { x: 16; y: 24; glyph: modelData.glyph; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 24; color: Colors.text }
          Text { x: 56; y: 12; width: parent.width - 144; text: modelData.name; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; font.weight: Font.DemiBold; color: Colors.text }
          Text {
            x: 56; y: 38; width: parent.width - 144
            text: (modelData.state === "active" ? "Running" : "Stopped") + " · " + modelData.detail
            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: Colors.text_alt; elide: Text.ElideRight
          }
          PillButton {
            anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
            width: 72; height: 40; filled: true; inactiveFillColor: Colors.surface; textSize: 14; enabled: !root.busy
            text: root.busyAction === "service:" + modelData.service ? "…" : modelData.state === "active" ? "Stop" : "Start"
            onClicked: root.serviceAction(modelData.service, modelData.state === "active" ? "stop" : "start")
          }
        }
      }
    }
    Rectangle {
      y: 424; width: parent.width; height: 104; radius: 16; color: Colors.surface_alt
      R1Icon { x: 16; y: 16; glyph: root.inhibitor === "active" ? "\uf023" : "\uf09c"; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 24; color: Colors.text }
      Text { x: 56; y: 16; text: "Sleep is " + (root.inhibitor === "active" ? "blocked" : "allowed"); font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; color: Colors.text }
      Text {
        x: 16; y: 48; width: parent.width - 32
        text: "Battery safeguards remain active.\nService controls are independent of the mode."
        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: Colors.text_alt; wrapMode: Text.WordWrap
      }
    }
    Rectangle {
      id: errorCard
      y: 544; width: parent.width; height: errorLabel.implicitHeight + 32; radius: 16; color: Colors.surface_alt; visible: !!root.errorText
      Text {
        id: errorLabel
        x: 16; y: 16; width: parent.width - 32; text: root.errorText
        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; color: Tokens.errorText; wrapMode: Text.Wrap
      }
    }
  }
  Item {
    visible: !!root.errorText && !!root.failedService
    width: parent.width; height: 376
    Row {
      spacing: 16
      R1Icon { iconName: "server"; font.pixelSize: 24; color: Colors.text; anchors.verticalCenter: parent.verticalCenter }
      Text { text: "Server mode"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 24; font.weight: Font.DemiBold; color: Colors.text }
    }
    Text {
      y: 64; width: parent.width
      text: "Couldn't " + root.failedServiceAction + " " + (root.failedService === "jellyfin" ? "Jellyfin" : "Tailscale")
      font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 20; font.weight: Font.DemiBold; color: Tokens.errorText; wrapMode: Text.WordWrap
    }
    Text {
      y: 112; width: parent.width; height: 64
      text: "Server mode is still " + (root.on ? "on" : "off") + ". You can retry or leave the service unchanged.\n" + root.errorText
      font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: Colors.text_alt; wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight
    }
    Rectangle {
      y: 192; width: parent.width; height: 72; radius: 16; color: Colors.primary_container
      R1Icon { x: 16; y: 24; iconName: root.failedService === "jellyfin" ? "globe" : "play"; font.pixelSize: 24; color: Colors.text }
      Text { x: 56; y: 12; text: root.failedService === "jellyfin" ? "Tailscale" : "Jellyfin"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; color: Colors.text }
      Text { x: 56; y: 38; text: (root.failedService === "jellyfin" ? root.tailscale : root.jellyfin) === "active" ? "Running · Unaffected" : "Stopped · Unaffected"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: Colors.text_alt }
    }
    Row {
      y: 336; width: parent.width; spacing: 8
      PillButton { width: (parent.width - 8) / 2; height: 40; filled: true; text: "Close"; textSize: 14; onClicked: root.close() }
      PillButton { width: (parent.width - 8) / 2; height: 40; active: true; text: "Retry service"; textSize: 14; onClicked: root.serviceAction(root.failedService, root.failedServiceAction) }
    }
  }
}
