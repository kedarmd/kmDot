import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs
import "../components"
import "../components/notificationidentity.js" as Identity

PopupBase {
  id: root
  sockName: "kmdot-notifications"
  animatePresentation: !Tokens.reducedMotion
  cardWidth: 424
  cardChrome: 48
  readonly property real panelHeight: Math.min(760, root.height - 80)
  cardMinHeight: panelHeight
  cardMaxHeight: panelHeight

  property int maxHistory: 100
  property var groups: []
  property bool historyReady: false
  property bool animateGroups: false

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
    let changed = false
    const tracked = notifServer.trackedNotifications.values || []
    for (let i = 0; i < tracked.length; i++) {
      const n = tracked[i]
      let found = false
      for (let j = 0; j < historyModel.count; j++) {
        const h = historyModel.get(j)
        if (h.liveId === n.id) { found = true; break }
      }
      if (!found) {
        changed = true
        historyModel.insert(0, {
          liveId: n.id,
          appName: n.appName || "",
          appIcon: Identity.sourceIcon(n),
          desktopEntry: n.desktopEntry || "",
          summary: n.summary || "",
          body: n.body || "",
          urgency: n.urgency,
          hasInlineReply: !!n.hasInlineReply,
          timestamp: Date.now()
        })
      }
    }
    if (changed) { saveHistory(); rebuildGroups() }
  }

  function addToHistory(notif) {
    // Replacement notifications update their existing record.
    for (let i = historyModel.count - 1; i >= 0; i--) {
      if (historyModel.get(i).liveId === notif.id) historyModel.remove(i)
    }
    historyModel.insert(0, {
      liveId: notif.id,
      appName: notif.appName || "",
      appIcon: Identity.sourceIcon(notif),
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
  }

  function rebuildGroups() {
    root.animateGroups = false
    const oldY = groupsViewport.contentY
    let anchor = null
    for (let i = 0; i < groupsRepeater.count; i++) {
      const item = groupsRepeater.itemAt(i)
      if (item && item.y + item.height > oldY) {
        anchor = { name: item.groupData.appName, offset: oldY - item.y }
        if (item.groupData.expanded) {
          for (let j = 0; j < item.entryItems.count; j++) {
            const row = item.entryItems.itemAt(j)
            const top = item.y + 56 + row.y
            if (top + row.height > oldY) {
              anchor.entryTime = row.modelData.timestamp
              anchor.entryId = row.modelData.liveId
              anchor.offset = oldY - top
              break
            }
          }
        }
        break
      }
    }
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
      map[key].appIcon = n.appIcon || ""
      map[key].desktopEntry = n.desktopEntry || ""
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

    // Keep existing source order while the reader has the panel open.
    if (root.opened && root.groups.length) {
      const order = root.groups.map(g => g.appName)
      newGroups.sort((a,b) => {
        const ai = order.indexOf(a.appName), bi = order.indexOf(b.appName)
        return (ai < 0 ? order.length : ai) - (bi < 0 ? order.length : bi)
      })
    }
    root.groups = newGroups
    if (root.opened && anchor) Qt.callLater(() => {
      for (let i = 0; i < groupsRepeater.count; i++) {
        const item = groupsRepeater.itemAt(i)
        if (item && item.groupData.appName === anchor.name) {
          let top = item.y
          if (anchor.entryTime !== undefined && item.groupData.expanded) {
            for (let j = 0; j < item.entryItems.count; j++) {
              const row = item.entryItems.itemAt(j)
              if (row.modelData.timestamp === anchor.entryTime && row.modelData.liveId === anchor.entryId) {
                top += 56 + row.y; break
              }
            }
          }
          groupsViewport.contentY = Math.max(0, Math.min(top + anchor.offset, groupsViewport.contentHeight - groupsViewport.height)); break
        }
      }
    })
  }

  function revealNotification(id) {
    root.open()
    const g = root.groups.find(g => g.entries.some(e => e.liveId === id))
    if (!g) return
    root.groups = root.groups.map(group => group.appName === g.appName
      ? Object.assign({}, group, {expanded: true}) : group)
    Qt.callLater(() => {
      const i = root.groups.findIndex(group => group.appName === g.appName)
      const item = groupsRepeater.itemAt(i)
      if (item) groupsViewport.contentY = Math.max(0, Math.min(item.y, groupsViewport.contentHeight - groupsViewport.height))
    })
  }

  function toggleGroup(appName) {
    root.animateGroups = true
    root.groups = root.groups.map(g => g.appName === appName
      ? Object.assign({}, g, {expanded: !g.expanded}) : g)
  }

  function saveHistory() {
    if (!root.historyReady) return
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

    onLoadFailed: { root.historyReady = true; root.saveHistory() }
    onLoaded: {
      if (root.historyReady) return
      const content = historyFileView.text()
      root.historyReady = true
      if (!content) { root.saveHistory(); return }
      try {
        const arr = JSON.parse(content)
        for (let i = 0; i < arr.length && i < root.maxHistory; i++) {
          const n = arr[i]
          if (historyModel.count >= root.maxHistory) break
          historyModel.append({
            liveId: -1,
            appName: n.appName || "",
            appIcon: n.appIcon || "",
            desktopEntry: n.desktopEntry || "",
            summary: n.summary || "",
            body: n.body || "",
            urgency: n.urgency === undefined ? 1 : n.urgency,
            timestamp: n.timestamp || Date.now()
          })
        }
        rebuildGroups()
        saveHistory()
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

  Item {
    width: parent.width; height: 108
    Row {
      width: parent.width; height: 34; spacing: 16
      R1Icon { anchors.verticalCenter: parent.verticalCenter; glyph: ""; font.pixelSize: 24; color: Colors.text }
      Text { anchors.verticalCenter: parent.verticalCenter; text: "Notifications"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 24; font.weight: Font.DemiBold; color: Colors.text }
    }

    Item {
      y: 72; width: parent.width; height: 46
      Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "Do not disturb"; color: Colors.text; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16; font.weight: Font.DemiBold }
      Rectangle {
        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
        width: 52; height: 30; radius: 15
        color: DnDState.dndEnabled ? Colors.primary : Tokens.outlineVariant
        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          x: DnDState.dndEnabled ? parent.width - width - 4 : 4
          width: 22; height: 22; radius: 11
          color: DnDState.dndEnabled ? Colors.base : Colors.text_alt
          Behavior on x { NumberAnimation { duration: Tokens.notificationMotion } }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: DnDState.dndEnabled = !DnDState.dndEnabled }
      }
    }

  }

  Text { width: parent.width; height: 17; text: root.groups.length ? "TODAY" : ""; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: Colors.text_alt }

  Flickable {
    id: groupsViewport
    width: parent.width
    height: Math.max(0, root.panelHeight - 277)
    contentHeight: root.groups.length ? groupsContent.implicitHeight : height
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick

    Column {
      anchors.horizontalCenter: parent.horizontalCenter
      y: Math.max(0, Math.min(131, (parent.height - implicitHeight) / 2))
      width: parent.width
      visible: !root.groups.length
      spacing: 24
      R1Icon { anchors.horizontalCenter: parent.horizontalCenter; glyph: "\uf0f3"; font.pixelSize: 24; color: Colors.text_alt }
      Text { width: parent.width; text: "You’re all caught up"; horizontalAlignment: Text.AlignHCenter; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16; color: Colors.text }
    }

    Column {
      id: groupsContent
      width: parent.width
      spacing: 16
      Repeater {
        id: groupsRepeater
        // Stable delegates when a group's content/expanded state changes.
        model: root.groups.length
        delegate: Rectangle {
          id: groupCard
          required property int index
          property alias entryItems: entryRepeater
          readonly property var groupData: root.groups[index]
          width: groupsContent.width
          height: 32 + groupHeader.height + 16 + (groupData.expanded ? entries.implicitHeight : collapsed.implicitHeight)
          radius: 24
          color: Colors.surface_high
          clip: true
          Behavior on height { enabled: root.animateGroups; NumberAnimation { duration: Tokens.notificationMotion; easing.type: Easing.OutCubic } }

          Item {
            id: groupHeader
            x: 16; y: 16; width: parent.width - 32; height: 24
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleGroup(groupCard.groupData.appName) }
            NotificationIcon { desktopEntry: groupCard.groupData.desktopEntry; appIcon: groupCard.groupData.appIcon; appName: groupCard.groupData.appName }
            Text {
              x: 36; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 108
              text: groupCard.groupData.appName + " · " + groupCard.groupData.entries.length
              font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; font.weight: Font.DemiBold; color: Colors.text; elide: Text.ElideRight
            }
            R1Icon {
              anchors.right: dismissGroupButton.left; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
              glyph: "\uf107"; font.pixelSize: 16; color: Colors.text_alt
              rotation: groupCard.groupData.expanded ? 180 : 0
              Behavior on rotation { NumberAnimation { duration: Tokens.notificationMotion; easing.type: Easing.OutCubic } }
            }
            R1Icon {
              id: dismissGroupButton
              anchors.right: parent.right; width: 24; height: 24; glyph: "\uf00d"; font.pixelSize: 16; color: Colors.text_alt
              horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.dismissGroup(groupCard.groupData.appName) }
            }
          }
          Column {
            id: collapsed
            x: 16; y: 56; width: parent.width - 32; spacing: 8
            visible: !groupCard.groupData.expanded
            Text { width: parent.width; text: groupCard.groupData.entries[0].summary; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; color: Colors.text; elide: Text.ElideRight }
            Text {
              width: parent.width; text: groupCard.groupData.entries.length + (groupCard.groupData.entries.length === 1 ? " notification · Show all" : " notifications · Show all")
              font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: Colors.text_alt
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleGroup(groupCard.groupData.appName) }
            }
          }
          Column {
            id: entries
            x: 16; y: 56; width: parent.width - 32; spacing: 16
            visible: groupCard.groupData.expanded
            Repeater {
              id: entryRepeater
              model: groupCard.groupData.entries
              delegate: Column {
                id: entry
                required property var modelData
                required property int index
                readonly property var live: root.findLiveById(modelData.liveId)
                width: entries.width
                spacing: 8
                Item {
                  width: parent.width; height: Math.max(24, summary.implicitHeight)
                  Text {
                    id: summary
                    width: parent.width - 100; text: entry.modelData.summary
                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; font.weight: Font.DemiBold
                    wrapMode: Text.Wrap; color: entry.modelData.urgency === 2 ? Colors.error : Colors.text
                  }
                  Text { anchors.right: entryClose.left; anchors.rightMargin: 8; text: root.relativeTime(entry.modelData.timestamp); font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: Colors.text_alt }
                  R1Icon {
                    id: entryClose
                    anchors.right: parent.right; width: 24; height: 24; glyph: "\uf00d"; font.pixelSize: 16; color: Colors.text_alt
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.dismissEntry(entry.modelData) }
                  }
                }
                Text {
                  width: parent.width; visible: text !== ""; text: entry.modelData.body
                  font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; lineHeightMode: Text.FixedHeight; lineHeight: 17
                  color: Colors.text_alt; wrapMode: Text.Wrap; textFormat: Text.PlainText
                }
                Item {
                  width: parent.width
                  height: actions.visible ? actions.implicitHeight + 8 : 0
                  Flow {
                    id: actions
                    y: 8; anchors.right: parent.right; width: parent.width
                    layoutDirection: Qt.RightToLeft; spacing: 8
                    visible: !!entry.live && (entry.live.actions.length > 0 || entry.live.hasInlineReply)
                    Repeater {
                      model: entry.live ? entry.live.actions : []
                      PillButton {
                        required property var modelData
                        width: Math.min(implicitWidth, entries.width)
                        height: 40; textSize: 12; filled: true; active: true; text: modelData.text || "Open"
                        onClicked: { modelData.invoke(); root.dismissEntry(entry.modelData) }
                      }
                    }
                    PillButton { visible: !!entry.live && entry.live.hasInlineReply; height: 40; text: "Reply"; textSize: 12; filled: true; active: true; onClicked: root.openReply(entry.modelData) }
                  }
                }
                Rectangle { width: parent.width; height: 1; visible: entry.index < groupCard.groupData.entries.length - 1; color: Colors.outline_variant }
              }
            }
          }
        }
      }
    }
  }

  bottomContent: Item {
    width: parent.width; height: 56
    Rectangle { width: parent.width; height: 1; color: Colors.outline_variant }
    Text { anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.bottomMargin: 12; text: historyModel.count + (historyModel.count === 1 ? " notification" : " notifications"); font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: Colors.text_alt }
    PillButton { anchors.right: parent.right; anchors.bottom: parent.bottom; width: 120; height: 40; filled: true; active: true; text: "Clear all"; visible: historyModel.count > 0; onClicked: root.clearAll() }
  }
}
