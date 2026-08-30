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
  property var groups: []

  readonly property string historyPath: {
    const cache = Quickshell.env("XDG_CACHE_HOME")
    const dir = cache ? cache : (Quickshell.env("HOME") + "/.cache")
    return dir + "/kmdot/notification_history.json"
  }

  readonly property string sockPath: {
    const rt = Quickshell.env("XDG_RUNTIME_DIR")
    return (rt ? rt : "/tmp") + "/kmdot-notifications.sock"
  }

  function findLiveById(id) {
    const tracked = notifServer.trackedNotifications.values || []
    for (let i = 0; i < tracked.length; i++) {
      if (tracked[i].id === id) return tracked[i]
    }
    return null
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
    const tracked = notifServer.trackedNotifications.values || []
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
          desktopEntry: n.desktopEntry || "",
          summary: n.summary || "",
          body: n.body || "",
          urgency: n.urgency,
          timestamp: Date.now()
        })
      }
    }
    saveHistory()
    rebuildGroups()
  }

  function addToHistory(notif) {
    historyModel.insert(0, {
      liveId: -1,
      appName: notif.appName || "",
      appIcon: notif.appIcon || "",
      desktopEntry: notif.desktopEntry || "",
      summary: notif.summary || "",
      body: notif.body || "",
      urgency: notif.urgency,
      timestamp: Date.now()
    })
    while (historyModel.count > root.maxHistory)
      historyModel.remove(historyModel.count - 1)
    saveHistory()
    rebuildGroups()
  }

  function dismissEntry(entry) {
    if (entry.liveId > 0) {
      const live = root.findLiveById(entry.liveId)
      if (live) live.dismiss()
    }
    for (let i = historyModel.count - 1; i >= 0; i--) {
      const n = historyModel.get(i)
      if (n.liveId === entry.liveId && n.summary === entry.summary && n.timestamp === entry.timestamp) {
        historyModel.remove(i)
        break
      }
    }
    saveHistory()
    rebuildGroups()
  }

  function dismissGroup(appName) {
    const tracked = notifServer.trackedNotifications.values || []
    for (let i = 0; i < tracked.length; i++) {
      if (tracked[i].appName === appName) tracked[i].dismiss()
    }
    for (let i = historyModel.count - 1; i >= 0; i--) {
      if (historyModel.get(i).appName === appName)
        historyModel.remove(i)
    }
    saveHistory()
    rebuildGroups()
  }

  function clearAll() {
    const tracked = notifServer.trackedNotifications.values || []
    for (let i = 0; i < tracked.length; i++)
      tracked[i].dismiss()
    historyModel.clear()
    saveHistory()
    root.groups = []
    root.close()
  }

  function resolveIcon(desktopEntry, appIcon) {
    const de = desktopEntry || ""
    const ic = appIcon || ""
    const name = de !== "" ? de : ic
    if (name === "") return ""
    if (name.startsWith("/") || name.startsWith("file://") || name.startsWith("image://")) return name
    return Quickshell.iconPath(name)
  }

  function rebuildGroups() {
    const map = {}
    const order = []
    for (let i = historyModel.count - 1; i >= 0; i--) {
      const n = historyModel.get(i)
      const key = n.appName || "(unknown)"
      if (!map[key]) {
        map[key] = {
          appName: key,
          appIcon: n.appIcon || "",
          desktopEntry: n.desktopEntry || "",
          entries: [],
          expanded: false
        }
        order.push(key)
      }
      map[key].entries.push({
        liveId: n.liveId,
        appName: n.appName,
        summary: n.summary,
        body: n.body,
        urgency: n.urgency,
        timestamp: n.timestamp
      })
    }
    const oldExpanded = {}
    for (let i = 0; i < root.groups.length; i++)
      oldExpanded[root.groups[i].appName] = root.groups[i].expanded

    const newGroups = []
    for (let i = 0; i < order.length; i++) {
      const g = map[order[i]]
      g.entries.reverse()
      g.expanded = oldExpanded[g.appName] || false
      newGroups.push(g)
    }
    root.groups = newGroups
  }

  function toggleGroup(appName) {
    const g = root.groups.find(g => g.appName === appName)
    if (g) {
      g.expanded = !g.expanded
      root.groups = root.groups.slice()
    }
  }

  function saveHistory() {
    const arr = []
    for (let i = 0; i < historyModel.count; i++) {
      const n = historyModel.get(i)
      arr.push({
        appName: n.appName,
        appIcon: n.appIcon,
        desktopEntry: n.desktopEntry,
        summary: n.summary,
        body: n.body,
        urgency: n.urgency,
        timestamp: n.timestamp
      })
    }
    historyFileView.setText(JSON.stringify(arr))
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
            desktopEntry: n.desktopEntry || "",
            summary: n.summary || "",
            body: n.body || "",
            urgency: n.urgency || 1,
            timestamp: n.timestamp || Date.now()
          })
        }
        rebuildGroups()
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
            glyph: DnDState.dndEnabled ? "\uf0e1" : "\uf0e2"
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
          visible: root.groups.length === 0
          text: "No notifications"
          font.family: "JetBrainsMono Nerd Font Propo"
          font.pixelSize: 13
          color: Colors.muted
          horizontalAlignment: Text.AlignHCenter
          topPadding: 40
          bottomPadding: 40
        }

        Repeater {
          id: groupsRepeater
          model: root.groups

          delegate: Column {
            id: groupCol
            width: cardBody.width
            property var groupData: modelData

            Rectangle {
              width: groupCol.width
              height: groupCol.groupData.expanded
                ? groupHeaderCol.height + expandedCol.height + 8
                : collapsedRow.height
              radius: 8
              color: groupHover.containsMouse ? Tokens.stateHover : "transparent"

              MouseArea {
                id: groupHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleGroup(groupCol.groupData.appName)
              }

              Column {
                anchors {
                  left: parent.left
                  right: parent.right
                  margins: 10
                }
                spacing: 4

                Row {
                  id: collapsedRow
                  visible: !groupCol.groupData.expanded
                  width: parent.width
                  spacing: 8
                  height: 36

                  Image {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.resolveIcon(groupCol.groupData.desktopEntry, groupCol.groupData.appIcon) !== ""
                    source: root.resolveIcon(groupCol.groupData.desktopEntry, groupCol.groupData.appIcon)
                    width: 22
                    height: 22
                    sourceSize: Qt.size(22, 22)
                    smooth: true
                  }

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.resolveIcon(groupCol.groupData.desktopEntry, groupCol.groupData.appIcon) === ""
                    text: "\uf0f3"
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 14
                    color: Colors.text
                  }

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: groupCol.groupData.appName
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: Colors.text
                    elide: Text.ElideRight
                    width: parent.width - 120
                  }

                  Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    height: 18
                    width: countText.implicitWidth + 10
                    radius: 9
                    color: Colors.primary
                    visible: groupCol.groupData.entries.length > 1

                    Text {
                      id: countText
                      anchors.centerIn: parent
                      text: groupCol.groupData.entries.length
                      font.family: "JetBrainsMono Nerd Font Propo"
                      font.pixelSize: 10
                      font.weight: Font.Bold
                      color: Colors.surface
                    }
                  }

                  Item { width: 1; height: 1 }

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.relativeTime(groupCol.groupData.entries[groupCol.groupData.entries.length - 1].timestamp)
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
                      onClicked: root.dismissGroup(groupCol.groupData.appName)
                    }
                  }
                }

                Column {
                  id: groupHeaderCol
                  visible: groupCol.groupData.expanded
                  width: parent.width
                  spacing: 4

                  Row {
                    width: parent.width
                    spacing: 8
                    height: 36

                    Image {
                      anchors.verticalCenter: parent.verticalCenter
                      visible: root.resolveIcon(groupCol.groupData.desktopEntry, groupCol.groupData.appIcon) !== ""
                      source: root.resolveIcon(groupCol.groupData.desktopEntry, groupCol.groupData.appIcon)
                      width: 20
                      height: 20
                      sourceSize: Qt.size(20, 20)
                      smooth: true
                    }

                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      visible: root.resolveIcon(groupCol.groupData.desktopEntry, groupCol.groupData.appIcon) === ""
                      text: "\uf0f3"
                      font.family: "JetBrainsMono Nerd Font Propo"
                      font.pixelSize: 14
                      color: Colors.text
                    }

                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      text: groupCol.groupData.appName + (groupCol.groupData.entries.length > 1 ? " (" + groupCol.groupData.entries.length + ")" : "")
                      font.family: "JetBrainsMono Nerd Font Propo"
                      font.pixelSize: 13
                      font.weight: Font.DemiBold
                      color: Colors.text
                    }

                    Item { width: 1; height: 1 }

                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      text: "\uf00d"
                      font.family: "JetBrainsMono Nerd Font Propo"
                      font.pixelSize: 11
                      color: Colors.muted

                      MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.dismissGroup(groupCol.groupData.appName)
                      }
                    }
                  }

                  Rectangle {
                    width: parent.width
                    height: 1
                    color: Tokens.divider
                  }
                }

                Column {
                  id: expandedCol
                  visible: groupCol.groupData.expanded
                  width: parent.width
                  spacing: 4

                  Repeater {
                    model: groupCol.groupData.entries

                    delegate: Rectangle {
                      width: expandedCol.width
                      height: entryInner.implicitHeight + 12
                      radius: 6
                      color: entryHover.containsMouse ? Tokens.stateHover : "transparent"
                      border.width: 1
                      border.color: Tokens.outlineVariant

                      MouseArea {
                        id: entryHover
                        anchors.fill: parent
                        hoverEnabled: true
                      }

                      Column {
                        id: entryInner
                        anchors {
                          left: parent.left
                          right: parent.right
                          verticalCenter: parent.verticalCenter
                          margins: 8
                        }
                        spacing: 1

                        Row {
                          width: parent.width
                          spacing: 4

                          Text {
                            text: modelData.summary || ""
                            font.family: "JetBrainsMono Nerd Font Propo"
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            color: modelData.urgency === 2 ? Colors.error : Colors.text
                            elide: Text.ElideRight
                            width: parent.width - 80
                          }

                          Text {
                            text: root.relativeTime(modelData.timestamp)
                            font.family: "JetBrainsMono Nerd Font Propo"
                            font.pixelSize: 9
                            color: Colors.muted
                          }

                          Text {
                            text: "\uf00d"
                            font.family: "JetBrainsMono Nerd Font Propo"
                            font.pixelSize: 10
                            color: Colors.muted

                            MouseArea {
                              anchors.fill: parent
                              cursorShape: Qt.PointingHandCursor
                              onClicked: root.dismissEntry(modelData)
                            }
                          }
                        }

                        Text {
                          width: parent.width
                          visible: text !== ""
                          text: modelData.body
                          font.family: "JetBrainsMono Nerd Font Propo"
                          font.pixelSize: 10
                          color: Colors.text_alt
                          elide: Text.ElideRight
                          maximumLineCount: 2
                          wrapMode: Text.Wrap
                          textFormat: Text.StyledText
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
