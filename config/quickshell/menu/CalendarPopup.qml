import QtQuick
import Quickshell
import Quickshell.Io
import qs
import "../components"

PopupBase {
  id: root
  sockName: "kmdot-calendar"
  cardWidth: 424
  cardMinHeight: 704
  focusItem: nav

  // Positioning/focus/socket shell lives in PopupBase (anchorItem seam).
  property var events: null
  property var cells: []
  property date today: new Date()
  property date selectedDay: new Date()
  property int year: root.today.getFullYear()
  property int monthIndex: root.today.getMonth()
  property string syncText: ""
  property bool loading: false

  readonly property var months: ["January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December"]
  readonly property var weekdays: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

  function pad(n) {
    return n < 10 ? "0" + n : "" + n
  }

  function fmtDate(d) {
    return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate())
  }

  function sameDate(a, b) {
    return a && b && a.getFullYear() === b.getFullYear()
      && a.getMonth() === b.getMonth() && a.getDate() === b.getDate()
  }

  function hasEvents(d) {
    const list = root.events ? root.events[root.fmtDate(d)] : null
    return list ? list.length > 0 : false
  }

  function dayEvents(d) {
    return root.events ? root.events[root.fmtDate(d)] || [] : []
  }

  function buildCells() {
    const y = root.year
    const m = root.monthIndex
    const first = new Date(y, m, 1).getDay()
    const arr = []
    for (let i = 0; i < 42; i++) {
      const d = new Date(y, m, i - first + 1)
      arr.push({
        date: d,
        inMonth: d.getMonth() === m,
        isToday: root.sameDate(d, root.today),
        isSelected: root.sameDate(d, root.selectedDay),
        hasEvents: root.hasEvents(d)
      })
    }
    root.cells = arr
  }

  function monthTitle() {
    return root.months[root.monthIndex] + " " + root.year
  }

  function selectedTitle() {
    return root.weekdays[root.selectedDay.getDay()] + ", "
      + root.months[root.selectedDay.getMonth()] + " " + root.selectedDay.getDate()
  }

  function shiftMonth(delta) {
    const d = new Date(root.year, root.monthIndex + delta, 1)
    root.year = d.getFullYear()
    root.monthIndex = d.getMonth()
    root.selectedDay = d
    root.buildCells()
  }

  function moveSelection(dx, dy) {
    const d = new Date(root.selectedDay.getFullYear(), root.selectedDay.getMonth(),
      root.selectedDay.getDate() + dx + dy)
    root.selectedDay = d
    if (d.getFullYear() !== root.year || d.getMonth() !== root.monthIndex) {
      root.year = d.getFullYear()
      root.monthIndex = d.getMonth()
    }
    root.buildCells()
  }

  function goToday() {
    root.today = new Date()
    root.year = root.today.getFullYear()
    root.monthIndex = root.today.getMonth()
    root.selectedDay = root.today
    root.buildCells()
  }

  function nowTime() {
    const d = new Date()
    const h = d.getHours()
    const m = d.getMinutes()
    const mm = m < 10 ? "0" + m : "" + m
    const ampm = h >= 12 ? "PM" : "AM"
    let h12 = h % 12
    if (h12 === 0) h12 = 12
    return h12 + ":" + mm + " " + ampm
  }

  function fmtTime12(hhmm) {
    const parts = hhmm.split(":")
    if (parts.length < 2) return hhmm
    let h = parseInt(parts[0], 10)
    const m = parts[1]
    const ampm = h >= 12 ? "PM" : "AM"
    h = h % 12
    if (h === 0) h = 12
    return h + ":" + m + " " + ampm
  }

  function eventTime(ev) {
    if (ev.a) return "All day"
    const s = root.fmtTime12(ev.s)
    if (ev.e) return s + " - " + root.fmtTime12(ev.e)
    return s
  }

  function syncNow() {
    root.loading = true
    root.syncText = "Syncing\u2026"
    syncProc.exec(["sh", "-c", "$HOME/.config/kmdot/quickshell/scripts/calendar-sync.sh --force"])
  }

  function refreshNow() {
    root.loading = true
    root.syncText = "Syncing\u2026"
    syncProc.exec(["sh", "-c", "$HOME/.config/kmdot/quickshell/scripts/calendar-sync.sh"])
  }

  function parseEvents() {
    root.loading = false
    parseProc.exec(["sh", "-c", "$HOME/.config/kmdot/quickshell/scripts/calendar-events.mjs"])
  }

  function refreshItems() {
    root.buildCells()
    root.syncText = "Syncing\u2026"
    root.loading = true
    root.refreshNow()
  }

  function openedChange() {
    if (root.opened) nav.forceActiveFocus()
  }

  Component.onCompleted: {
    root.buildCells()
    root.syncNow()
  }

  // Periodic resync while logged in.
  Timer {
    interval: 1800000
    repeat: true
    onTriggered: root.syncNow()
  }

  Process {
    id: syncProc
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function(data) {
        const line = String(data).trim()
        if (line) root.syncText = line
      }
    }
    onExited: {
      root.syncText = "Synced " + root.nowTime()
      root.parseEvents()
    }
  }

  Process {
    id: parseProc
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const obj = JSON.parse(String(this.text).trim())
          root.events = obj.events || {}
          if (obj.ok === false) root.syncText = "Calendar error"
        } catch (e) {
          root.events = {}
          root.syncText = "Calendar error"
        }
        root.buildCells()
      }
    }
  }

  Item {
    id: nav
    width: parent.width
    height: 592
    focus: true
    Keys.onEscapePressed: root.close()
    Keys.onUpPressed: root.moveSelection(0, -7)
    Keys.onDownPressed: root.moveSelection(0, 7)
    Keys.onLeftPressed: root.moveSelection(-1, 0)
    Keys.onRightPressed: root.moveSelection(1, 0)
    Keys.onEnterPressed: root.close()
    Keys.onReturnPressed: root.close()
    Keys.onPressed: event => {
      if (event.key === Qt.Key_PageUp) { root.shiftMonth(-1); event.accepted = true }
      else if (event.key === Qt.Key_PageDown) { root.shiftMonth(1); event.accepted = true }
    }

    Row {
      spacing: 16
      R1Icon { glyph: "\uf073"; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 24; color: Colors.text; anchors.verticalCenter: parent.verticalCenter }
      Text { text: root.monthTitle(); font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 24; font.weight: Font.DemiBold; color: Colors.text }
    }
    Text {
      y: 68; width: parent.width - 112
      text: root.weekdays[root.today.getDay()] + ", " + root.months[root.today.getMonth()] + " " + root.today.getDate()
      font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; color: Colors.text_alt; elide: Text.ElideRight
    }
    Row {
      y: 60; anchors.right: parent.right; spacing: 24
      Repeater {
        model: [-1, 1]
        PillButton {
          required property var modelData
          width: 40; height: 40; glyph: modelData < 0 ? "\uf053" : "\uf054"; glyphSize: 16
          onClicked: root.shiftMonth(modelData)
        }
      }
    }
    Row {
      y: 120; width: parent.width
      Repeater {
        model: ["S", "M", "T", "W", "T", "F", "S"]
        Text {
          required property var modelData
          width: parent.width / 7; height: 20; text: modelData
          font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: Colors.text_alt; horizontalAlignment: Text.AlignHCenter
        }
      }
    }
    Grid {
      y: 152; width: parent.width; columns: 7; rowSpacing: 4
      Repeater {
        model: root.cells
        Item {
          required property var modelData
          width: nav.width / 7; height: 40
          Rectangle {
            anchors.centerIn: parent; width: 40; height: 40; radius: 20
            color: modelData.isToday ? Colors.primary : modelData.isSelected ? Colors.primary_container : "transparent"
          }
          Text {
            anchors.centerIn: parent; text: modelData.date.getDate()
            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14
            color: modelData.isToday ? Colors.surface : modelData.inMonth ? Colors.text : Colors.text_alt
            opacity: modelData.inMonth ? 1 : 0.6
            font.weight: modelData.isToday || modelData.isSelected ? Font.DemiBold : Font.Normal
          }
          Rectangle {
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 4 }
            width: 3; height: 3; radius: 1.5; visible: modelData.hasEvents
            color: modelData.isToday ? Colors.surface : Colors.primary
          }
          MouseArea {
            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.selectedDay = modelData.date
              root.year = modelData.date.getFullYear()
              root.monthIndex = modelData.date.getMonth()
              root.buildCells()
            }
          }
        }
      }
    }
    Rectangle { y: 432; width: parent.width; height: 1; color: Colors.border }
    Text {
      y: 456; width: parent.width; text: root.selectedTitle().toUpperCase()
      font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: Colors.text_alt
    }
    Flickable {
      id: agenda
      y: 492; width: parent.width; height: 124; clip: true
      contentHeight: agendaRows.height
      Column {
        id: agendaRows
        width: parent.width; spacing: 12
        Repeater {
          model: root.dayEvents(root.selectedDay)
          Item {
            required property var modelData
            required property int index
            width: parent.width; height: 56
            Rectangle { width: 4; height: parent.height; color: index % 2 === 0 ? Colors.primary_alt : Colors.accent }
            Text {
              x: 16; width: parent.width - 16; text: root.eventTime(modelData)
              font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: Colors.text_alt
            }
            Item {
              id: titleClip
              x: 16; y: 24; width: parent.width - 16; height: 24; clip: true
              property bool marquee: false
              Text {
                id: shortTitle
                width: parent.width; visible: !titleClip.marquee
                text: modelData.t; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16; color: Colors.text; elide: Text.ElideRight
              }
              Text {
                id: longTitle
                visible: titleClip.marquee; text: modelData.t; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16; color: Colors.text
              }
              MouseArea {
                anchors.fill: parent; hoverEnabled: true
                onEntered: { if (shortTitle.implicitWidth > titleClip.width) { titleClip.marquee = true; marquee.restart() } }
                onExited: { marquee.stop(); titleClip.marquee = false }
              }
              NumberAnimation {
                id: marquee; target: longTitle; property: "x"; from: titleClip.width; to: -longTitle.implicitWidth
                duration: Math.max(1000, longTitle.implicitWidth * 12)
              }
            }
          }
        }
        Text {
          visible: root.dayEvents(root.selectedDay).length === 0
          text: "No events"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; color: Colors.text_alt
        }
      }
      Rectangle {
        anchors.right: parent.right; width: 3; radius: 2; color: Colors.border
        visible: agenda.contentHeight > agenda.height
        height: agenda.height * agenda.height / agenda.contentHeight
        y: agenda.contentY / agenda.contentHeight * agenda.height
      }
    }
  }
  bottomContent: Item {
    width: parent.width; height: 40
    Text {
      anchors.verticalCenter: parent.verticalCenter; width: parent.width - 136
      text: root.syncText; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: Colors.text_alt; elide: Text.ElideRight
    }
    PillButton {
      anchors.right: parent.right; width: 120; height: 40; filled: true; inactiveFillColor: Colors.surface_alt
      text: root.loading ? "Syncing…" : "Sync"; textSize: 14; enabled: !root.loading
      onClicked: root.syncNow()
    }
  }
}
