import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs
import "../components"

PopupBase {
  id: root
  sockName: "kmdot-notifications"
  cardWidth: 424
  cardChrome: 48
  cardMinHeight: root.groups.length > 0 ? 688 : 400
  cardMaxHeight: Math.min(688, root.height - 80)

  property int maxHistory: 100
  property var groups: []

  readonly property string historyPath: {
    const cache = Quickshell.env("XDG_CACHE_HOME")
    const dir = cache ? cache : (Quickshell.env("HOME") + "/.cache")
    return dir + "/kmdot/notification_history.json"
  }

  function findLiveById(id) {
    const tracked = notifServer.trackedNotifications.values || []
    for (let i = 0; i < tracked.length; i++) {
      if (tracked[i].id === id) return tracked[i]
    }
    return null
  }

  function refreshItems() {
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
          hasInlineReply: !!n.hasInlineReply,
          timestamp: Date.now()
        })
      }
    }
    saveHistory()
    rebuildGroups()
  }

  function addToHistory(notif) {
    historyModel.insert(0, {
      liveId: notif.id,
      appName: notif.appName || "",
      appIcon: notif.appIcon || "",
      desktopEntry: notif.desktopEntry || "",
      summary: notif.summary || "",
      body: notif.body || "",
      urgency: notif.urgency,
      hasInlineReply: !!notif.hasInlineReply,
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

  function openReply(entry) {
    if (!entry || entry.liveId <= 0 || !root.scope || !root.scope.notificationReplyPopup) return
    const notif = root.findLiveById(entry.liveId)
    if (!notif || !notif.hasInlineReply) return
    const group = root.groups.find(g => g.appName === entry.appName)
    const thread = group ? group.entries.slice().reverse().map(e => ({
      text: [e.summary, e.body].filter(Boolean).join("\n"),
      when: root.relativeTime(e.timestamp)
    })) : []
    root.scope.notificationReplyPopup.present(notif, thread)
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
        hasInlineReply: !!n.hasInlineReply,
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
      g.expanded = Object.prototype.hasOwnProperty.call(oldExpanded, g.appName)
        ? oldExpanded[g.appName]
        : false
      newGroups.push(g)
    }
    newGroups.sort((a, b) => {
      const aTime = a.entries.length ? a.entries[0].timestamp : 0
      const bTime = b.entries.length ? b.entries[0].timestamp : 0
      return bTime - aTime
    })
    if (root.groups.length === 0 && newGroups.length > 0)
      newGroups[0].expanded = true
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

  Timer {
    interval: 3000
    repeat: true
    running: root.opened
    onTriggered: root.refreshItems()
  }

  Row {
    id: headerRow
    width: parent.width
    height: 48
    spacing: 16

    R1Icon {
      anchors.verticalCenter: parent.verticalCenter
      glyph: ""
      font.family: "JetBrainsMono Nerd Font Propo"
      font.pixelSize: 24
      color: Colors.text
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: "Notifications"
      font.family: "JetBrainsMono Nerd Font"
      font.pixelSize: 24
      font.weight: Font.DemiBold
      color: Colors.text
    }

    Item { width: 1; height: 1 }
  }

  Item {
    width: parent.width
    height: 64

    Column {
      anchors.left: parent.left
      anchors.right: dndSwitch.left
      anchors.rightMargin: 12
      anchors.verticalCenter: parent.verticalCenter
      spacing: 2

      Text { text: "Do not disturb"; color: Colors.text; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16; font.weight: Font.DemiBold }
      Text { width: parent.width; text: root.groups.length === 0 && !DnDState.dndEnabled ? "Notifications are allowed" : "Quiet notifications until you turn it off"; color: Colors.text_alt; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; wrapMode: Text.WordWrap }
    }

    Rectangle {
      id: dndSwitch
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      width: 52
      height: 30
      radius: 15
      color: DnDState.dndEnabled ? Colors.primary : Tokens.outlineVariant

      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: DnDState.dndEnabled ? parent.width - width - 4 : 4
        width: 22
        height: 22
        radius: 11
        color: DnDState.dndEnabled ? Colors.base : Colors.text_alt
        Behavior on x { NumberAnimation { duration: 140 } }
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: DnDState.dndEnabled = !DnDState.dndEnabled
      }
    }
  }

  Text {
    width: parent.width
    visible: root.groups.length > 0
    text: "TODAY"
    font.family: "JetBrainsMono Nerd Font"
    font.pixelSize: 12
    color: Colors.text_alt
  }

  Flickable {
    id: groupsViewport
    width: parent.width
    height: Math.min(groupsContent.implicitHeight, Math.max(120, Math.min(400, root.height - 330)))
    contentHeight: groupsContent.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick

    Column {
      id: groupsContent
      width: parent.width - 12
      spacing: 12

      Column {
        width: parent.width
        visible: root.groups.length === 0
        spacing: 24
        Item { width: 1; height: 24 }
        R1Icon { anchors.horizontalCenter: parent.horizontalCenter; iconName: "check"; font.pixelSize: 24; color: Colors.text }
        Text { width: parent.width; text: "All caught up."; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 24; font.weight: Font.DemiBold; color: Colors.text; horizontalAlignment: Text.AlignHCenter }
        Text { width: parent.width; text: "New notifications will appear here."; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; color: Colors.text_alt; horizontalAlignment: Text.AlignHCenter }
      }

      Repeater {
        id: groupsRepeater
        model: root.groups

        delegate: Column {
      id: groupCol
      width: groupsContent.width
      property var groupData: modelData

      Rectangle {
        width: groupCol.width
        height: groupCol.groupData.expanded
          ? groupHeaderCol.height + expandedCol.height + 8
          : collapsedRow.height + collapsedSummary.implicitHeight + 12
        radius: 16
        color: groupHover.containsMouse ? Tokens.surfaceContainerHighest : Tokens.surfaceContainer

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

            R1Icon {
              anchors.verticalCenter: parent.verticalCenter
              visible: root.resolveIcon(groupCol.groupData.desktopEntry, groupCol.groupData.appIcon) === ""
              glyph: ""
              font.family: "JetBrainsMono Nerd Font Propo"
              font.pixelSize: 14
              color: Colors.text
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: groupCol.groupData.appName + (groupCol.groupData.entries.length > 1 ? " · " + groupCol.groupData.entries.length : "")
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 14
              font.weight: Font.DemiBold
              color: Colors.text
              elide: Text.ElideRight
              width: parent.width - 120
            }

            Item { width: 1; height: 1 }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: root.relativeTime(groupCol.groupData.entries[0].timestamp)
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 12
              color: Tokens.mutedText
            }

            Item {
              anchors.verticalCenter: parent.verticalCenter
              width: 24
              height: 24

              R1Icon {
                anchors.centerIn: parent
                glyph: ""
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 16
                color: Colors.text_alt
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  mouse.accepted = true
                  root.dismissGroup(groupCol.groupData.appName)
                }
              }
            }
          }

          Text {
            id: collapsedSummary
            visible: !groupCol.groupData.expanded
            width: parent.width
            text: groupCol.groupData.entries.length > 0 ? groupCol.groupData.entries[0].summary : ""
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            color: Colors.text_alt
            elide: Text.ElideRight
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

              R1Icon {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.resolveIcon(groupCol.groupData.desktopEntry, groupCol.groupData.appIcon) === ""
                glyph: ""
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 14
                color: Colors.text
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: groupCol.groupData.appName + (groupCol.groupData.entries.length > 1 ? " · " + groupCol.groupData.entries.length : "")
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 14
                font.weight: Font.DemiBold
                color: Colors.text
                elide: Text.ElideRight
                width: parent.width - 60
              }

              Item {
                anchors.verticalCenter: parent.verticalCenter
                width: 24
                height: 24

                R1Icon {
                  anchors.centerIn: parent
                  glyph: ""
                  font.family: "JetBrainsMono Nerd Font Propo"
                  font.pixelSize: 16
                  color: Colors.text_alt
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    mouse.accepted = true
                    root.dismissGroup(groupCol.groupData.appName)
                  }
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
                id: notificationEntry
                required property var modelData
                required property int index
                readonly property var liveNotification: root.findLiveById(modelData.liveId)
                width: expandedCol.width
                height: entryInner.implicitHeight + 12
                radius: 8
                color: entryHover.containsMouse ? Tokens.stateHover : "transparent"
                border.width: 0

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
                    leftMargin: 8
                    rightMargin: 0
                  }
                  spacing: 1

                  Row {
                    id: entryHeaderRow
                    width: parent.width
                    spacing: 4

                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      text: modelData.summary || ""
                      font.family: "JetBrainsMono Nerd Font"
                      font.pixelSize: index === 0 ? 16 : 12
                      font.weight: index === 0 ? Font.Bold : Font.Normal
                      color: modelData.urgency === 2 ? Colors.error : Colors.text
                      elide: Text.ElideRight
                      width: Math.max(0, parent.width - entryTime.implicitWidth - entryClose.width - entryHeaderRow.spacing * 2)
                    }

                    Text {
                      id: entryTime
                      anchors.verticalCenter: parent.verticalCenter
                      text: root.relativeTime(modelData.timestamp)
                      font.family: "JetBrainsMono Nerd Font"
                      font.pixelSize: 12
                      color: Tokens.mutedText
                    }

                    Item {
                      id: entryClose
                      anchors.verticalCenter: parent.verticalCenter
                      width: 24
                      height: 24

                      R1Icon {
                        anchors.centerIn: parent
                        glyph: ""
                        font.family: "JetBrainsMono Nerd Font Propo"
                        font.pixelSize: 16
                        color: Colors.text_alt
                      }

                      MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          mouse.accepted = true
                          root.dismissEntry(modelData)
                        }
                      }
                    }
                  }

                  Text {
                    width: parent.width
                    visible: index === 0 && text !== ""
                    text: modelData.body
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: index === 0 ? 14 : 12
                    color: Colors.text_alt
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                    textFormat: Text.StyledText
                  }

                  Flow {
                    width: parent.width
                    spacing: 8
                    visible: notificationEntry.index === 0 && !!notificationEntry.liveNotification
                    Repeater {
                      model: notificationEntry.liveNotification ? notificationEntry.liveNotification.actions : []
                      PillButton {
                        required property var modelData
                        height: 40; textSize: 14; filled: true; active: true
                        text: modelData.text || "Open"
                        onClicked: {
                          modelData.invoke()
                          root.dismissEntry(notificationEntry.modelData)
                        }
                      }
                    }
                    PillButton {
                      visible: !!notificationEntry.liveNotification && notificationEntry.liveNotification.hasInlineReply
                      height: 40; text: "Reply"; textSize: 14; filled: true; active: true
                      onClicked: root.openReply(notificationEntry.modelData)
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

    Rectangle {
      visible: groupsViewport.contentHeight > groupsViewport.height
      anchors.right: parent.right
      width: 3
      height: parent.height
      radius: 2
      color: Colors.surface_alt

      Rectangle {
        width: parent.width
        height: groupsViewport.contentHeight > 0
          ? Math.max(24, parent.height * groupsViewport.height / groupsViewport.contentHeight)
          : parent.height
        y: groupsViewport.contentHeight > groupsViewport.height
          ? groupsViewport.contentY * (parent.height - height) / (groupsViewport.contentHeight - groupsViewport.height)
          : 0
        radius: 2
        color: Tokens.mutedText
      }
    }
  }

  bottomContent: Item {
    width: parent.width
    height: root.groups.length > 0 ? 40 : 0
    visible: root.groups.length > 0
    Text {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: historyModel.count + (historyModel.count === 1 ? " notification" : " notifications")
      font.family: "JetBrainsMono Nerd Font"
      font.pixelSize: 12
      color: Tokens.mutedText
    }
    PillButton {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      width: 120
      height: 40
      filled: true
      active: true
      text: "Clear all"
      enabled: historyModel.count > 0
      onClicked: root.clearAll()
    }
  }
}
