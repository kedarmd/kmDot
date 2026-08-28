import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Wayland
import qs
import "../components"
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
  property var anchorItem: null
  property real anchorGX: -1
  property int maxHistory: 100

  readonly property string historyPath: {
    const cache = Quickshell.env("XDG_CACHE_HOME")
    const dir = cache ? cache : (Quickshell.env("HOME") + "/.cache")
    return dir + "/kmdot/notification_history.json"
  }

  readonly property string sockPath: {
    const rt = Quickshell.env("XDG_RUNTIME_DIR")
    return (rt ? rt : "/tmp") + "/kmdot-notifications.sock"
  }

  function pickScreen() {
    posProc.exec(["sh", "-c", "hyprctl cursorpos"])
  }

  function applyAnchor() {
    if (root.anchorItem) {
      const gx = Pos.globalCenterX(root.anchorItem)
      root.anchorItem = null
      if (gx >= 0) root.anchorGX = gx
    }
    if (root.anchorGX >= 0) {
      const s = Pos.screenFor(Quickshell.screens.values, root.anchorGX)
      if (s) root.screen = s
      else root.pickScreen()
    } else {
      root.pickScreen()
    }
  }

  function open() {
    if (root.scope && root.scope.activeLauncher) root.scope.activeLauncher.closeLauncher()
    if (root.scope && root.scope.batteryPopup) root.scope.batteryPopup.close()
    if (root.scope && root.scope.volumePopup) root.scope.volumePopup.close()
    if (root.scope && root.scope.calendarPopup) root.scope.calendarPopup.close()
    if (root.scope && root.scope.serverModeDropdown) root.scope.serverModeDropdown.close()
    if (root.scope && root.scope.displayPopup) root.scope.displayPopup.close()
    root.opened = true
    root.syncFromServer()
    root.applyAnchor()
    focusTimer.start()
  }

  function close() {
    root.opened = false
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function syncFromServer() {
    const tracked = scope.notifServer.trackedNotifications.values || []
    for (let i = 0; i < tracked.length; i++) {
      const n = tracked[i]
      let found = false
      for (let j = 0; j < historyModel.count; j++) {
        const h = historyModel.get(j)
        if (h.liveId === n.id) { found = true; break }
      }
      if (!found) {
        historyModel.insert(0, {
          liveId: n.id,
          appName: n.appName || "",
          appIcon: n.appIcon || "",
          summary: n.summary || "",
          body: n.body || "",
          urgency: n.urgency,
          timestamp: Date.now(),
          _ref: n
        })
      }
    }
    saveHistory()
  }

  function addToHistory(notif) {
    historyModel.insert(0, {
      liveId: -1,
      appName: notif.appName || "",
      appIcon: notif.appIcon || "",
      summary: notif.summary || "",
      body: notif.body || "",
      urgency: notif.urgency,
      timestamp: Date.now(),
      _ref: null
    })
    while (historyModel.count > root.maxHistory)
      historyModel.remove(historyModel.count - 1)
    saveHistory()
  }

  function dismissEntry(idx) {
    const entry = historyModel.get(idx)
    if (entry && entry._ref) entry._ref.dismiss()
    historyModel.remove(idx)
    saveHistory()
  }

  function clearAll() {
    const tracked = scope.notifServer.trackedNotifications.values || []
    for (let i = 0; i < tracked.length; i++)
      tracked[i].dismiss()
    historyModel.clear()
    saveHistory()
    root.close()
  }

  function saveHistory() {
    const arr = []
    for (let i = 0; i < historyModel.count; i++) {
      const n = historyModel.get(i)
      arr.push({
        appName: n.appName,
        appIcon: n.appIcon,
        summary: n.summary,
        body: n.body,
        urgency: n.urgency,
        timestamp: n.timestamp
      })
    }
    historyFileView.setText(JSON.stringify(arr))
  }

  function loadHistory() {
    historyFileView.reload()
  }

  function relativeTime(ts) {
    const diff = Math.floor((Date.now() - ts) / 1000)
    if (diff < 60) return "now"
    if (diff < 3600) return Math.floor(diff / 60) + "m ago"
    if (diff < 86400) return Math.floor(diff / 3600) + "h ago"
    return Math.floor(diff / 86400) + "d ago"
  }

  ListModel {
    id: historyModel
  }

  FileView {
    id: historyFileView
    path: root.historyPath
    watchChanges: false

    onLoaded: {
      const content = historyFileView.text()
      if (!content) return
      try {
        const arr = JSON.parse(content)
        historyModel.clear()
        for (let i = 0; i < arr.length && i < root.maxHistory; i++) {
          const n = arr[i]
          historyModel.insert(i, {
            liveId: -1,
            appName: n.appName || "",
            appIcon: n.appIcon || "",
            summary: n.summary || "",
            body: n.body || "",
            urgency: n.urgency || 1,
            timestamp: n.timestamp || Date.now(),
            _ref: null
          })
        }
      } catch (e) {
        console.log("Failed to parse notification history:", e)
      }
    }
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
    onTriggered: root.syncFromServer()
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
      width: 380
      height: Math.min(cardBody.implicitHeight + 24, root.height - 80)
      radius: 20
      color: Tokens.surfaceContainerLow

      anchors {
        top: parent.top
        topMargin: 48
      }
      x: root.anchorGX >= 0
        ? Pos.cardXFor(root.anchorGX, card.width, root.screen)
        : parent.width - card.width - 10

      MouseArea {
        anchors.fill: parent
      }

      Column {
        id: cardBody
        anchors {
          top: parent.top
          left: parent.left
          right: parent.right
          margins: 16
        }
        spacing: 12

        Row {
          id: headerRow
          width: parent.width
          spacing: 8

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "\uf0f3"
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 18
            color: Colors.text
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Notifications"
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 16
            font.weight: Font.DemiBold
            color: Colors.text
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: historyModel.count > 0
            text: historyModel.count
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 11
            color: Colors.muted
          }

          Item { width: 1; height: 1 }

          PillButton {
            anchors.verticalCenter: parent.verticalCenter
            height: 26
            active: DnDState.dndEnabled
            fillColor: DnDState.dndEnabled ? Colors.warning : "transparent"
            activeTextColor: DnDState.dndEnabled ? Colors.text : Colors.text_alt
            glyph: DnDState.dndEnabled ? "󰂛" : "󰂚"
            glyphSize: 11
            text: DnDState.dndEnabled ? "DnD On" : "DnD Off"
            textSize: 10
            horizontalPadding: 8
            onClicked: DnDState.dndEnabled = !DnDState.dndEnabled
          }

          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            height: 26
            width: clearRow.implicitWidth + 14
            radius: height / 2
            color: clearHover.containsMouse ? Tokens.stateHover : "transparent"
            border.width: 1
            border.color: Tokens.outlineVariant
            visible: historyModel.count > 0

            Row {
              id: clearRow
              anchors.centerIn: parent
              spacing: 4

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "\uf2ed"
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 10
                color: Colors.text_alt
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Clear"
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 10
                color: Colors.text_alt
              }
            }

            MouseArea {
              id: clearHover
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.clearAll()
            }
          }
        }

        Rectangle {
          width: parent.width
          height: 1
          color: Tokens.divider
        }

        Text {
          width: parent.width
          visible: historyModel.count === 0
          text: "No notifications"
          font.family: "JetBrainsMono Nerd Font Propo"
          font.pixelSize: 13
          color: Colors.muted
          horizontalAlignment: Text.AlignHCenter
          topPadding: 40
          bottomPadding: 40
        }

        ListView {
          id: notifList
          width: parent.width
          height: Math.min(historyModel.count * 80 + 8, root.height - 200)
          clip: true
          spacing: 8
          model: historyModel
          interactive: true
          flickDeceleration: 2000
          boundsBehavior: Flickable.StopAtBounds

          Rectangle {
            id: vBar
            visible: notifList.contentHeight > notifList.height
            width: 4
            radius: 2
            color: Colors.text_alt
            opacity: 0.4
            anchors.right: parent.right
            anchors.rightMargin: 2
            y: notifList.contentY * (notifList.height - vBar.height) / Math.max(1, notifList.contentHeight - notifList.height)
            height: Math.max(20, notifList.height * notifList.height / notifList.contentHeight)
          }

          delegate: Rectangle {
            id: row
            required property int index
            required property var modelData
            width: notifList.width
            height: rowBody.implicitHeight + 20
            radius: 12
            color: mouse.containsMouse ? Tokens.stateHover : "transparent"

            property bool isLive: modelData.liveId >= 0

            Column {
              id: rowBody
              anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: 10
              }
              spacing: 4

              Row {
                width: parent.width
                spacing: 8

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: modelData.appIcon ? modelData.appIcon : "\uf0f3"
                  font.family: "JetBrainsMono Nerd Font Propo"
                  font.pixelSize: 13
                  color: Colors.text_alt
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width - 100
                  text: modelData.appName || "Notification"
                  font.family: "JetBrainsMono Nerd Font Propo"
                  font.pixelSize: 11
                  font.weight: Font.DemiBold
                  color: Colors.text
                  elide: Text.ElideRight
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.relativeTime(modelData.timestamp)
                  font.family: "JetBrainsMono Nerd Font Propo"
                  font.pixelSize: 10
                  color: Colors.muted
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: "\uf00d"
                  font.family: "JetBrainsMono Nerd Font Propo"
                  font.pixelSize: 11
                  color: Colors.muted

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.dismissEntry(row.index)
                  }
                }
              }

              Text {
                width: parent.width
                visible: text !== ""
                text: modelData.summary
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 12
                font.weight: Font.Bold
                color: modelData.urgency === 2 ? Colors.error : Colors.text
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.Wrap
              }

              Text {
                width: parent.width
                visible: text !== ""
                text: modelData.body
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 11
                color: Colors.text_alt
                elide: Text.ElideRight
                maximumLineCount: 3
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
              }
            }

            MouseArea {
              id: mouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
            }
          }
        }
      }
    }
  }
}
