import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs

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
  property var events: null
  property var cells: []
  property date today: new Date()
  property date selectedDay: new Date()
  property int year: root.today.getFullYear()
  property int monthIndex: root.today.getMonth()
  property string syncText: ""
  property bool loading: false

  readonly property string sockPath: {
    const rt = Quickshell.env("XDG_RUNTIME_DIR")
    return (rt ? rt : "/tmp") + "/kmdot-calendar.sock"
  }

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

  function pickScreen() {
    posProc.exec(["sh", "-c", "hyprctl cursorpos"])
  }

  function open() {
    if (root.scope && root.scope.activeLauncher) root.scope.activeLauncher.closeLauncher()
    if (root.scope && root.scope.batteryPopup && root.scope.batteryPopup !== root) root.scope.batteryPopup.close()
    if (root.scope && root.scope.volumePopup && root.scope.volumePopup !== root) root.scope.volumePopup.close()
    if (root.scope && root.scope.brightnessPopup && root.scope.brightnessPopup !== root) root.scope.brightnessPopup.close()
    if (root.scope && root.scope.serverModeDropdown) root.scope.serverModeDropdown.close()
    root.opened = true
    root.pickScreen()
    root.buildCells()
    root.syncText = "Syncing\u2026"
    root.loading = true
    root.refreshNow()
    focusTimer.start()
  }

  function close() {
    root.opened = false
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  Component.onCompleted: {
    root.buildCells()
    root.syncNow()
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

  // Periodic resync while logged in.
  Timer {
    interval: 1800000
    repeat: true
    onTriggered: root.syncNow()
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
    Keys.onUpPressed: root.moveSelection(0, -7)
    Keys.onDownPressed: root.moveSelection(0, 7)
    Keys.onLeftPressed: root.moveSelection(-1, 0)
    Keys.onRightPressed: root.moveSelection(1, 0)
    Keys.onEnterPressed: root.close()
    Keys.onReturnPressed: root.close()
    Keys.onPressed: (event) => {
      if (event.key === Qt.Key_PageUp) {
        root.shiftMonth(-1)
        event.accepted = true
      } else if (event.key === Qt.Key_PageDown) {
        root.shiftMonth(1)
        event.accepted = true
      }
    }

    MouseArea {
      id: dismiss
      anchors.fill: parent
      onClicked: root.close()
    }

    Rectangle {
      id: card
      width: 340
      height: body.implicitHeight + 32
      radius: 12
      color: Colors.surface
      border.color: Colors.border
      border.width: 1

      anchors {
        top: parent.top
        topMargin: 48
        horizontalCenter: parent.horizontalCenter
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
        spacing: 12

        Row {
          width: parent.width
          height: 32
          spacing: 4

          Rectangle {
            id: prevBtn
            width: 32
            height: 32
            radius: 6
            color: mouse1.containsMouse ? Colors.surface_alt : "transparent"
            Text {
              anchors.centerIn: parent
              text: "\uf053"
              font.family: "JetBrainsMono Nerd Font Propo"
              font.pixelSize: 14
              color: Colors.text_alt
            }
            MouseArea {
              id: mouse1
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.shiftMonth(-1)
            }
          }

          Item {
            width: 1
            height: 1
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.monthTitle()
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 14
            font.weight: Font.DemiBold
            color: Colors.text
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
          }

          Item {
            width: 1
            height: 1
          }

          Rectangle {
            id: nextBtn
            width: 32
            height: 32
            radius: 6
            color: mouse2.containsMouse ? Colors.surface_alt : "transparent"
            Text {
              anchors.centerIn: parent
              text: "\uf054"
              font.family: "JetBrainsMono Nerd Font Propo"
              font.pixelSize: 14
              color: Colors.text_alt
            }
            MouseArea {
              id: mouse2
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.shiftMonth(1)
            }
          }
        }

        Row {
          width: parent.width
          spacing: 0
          Repeater {
            model: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
            Text {
              width: 44
              height: 20
              text: modelData
              font.family: "JetBrainsMono Nerd Font Propo"
              font.pixelSize: 10
              color: Colors.muted
              horizontalAlignment: Text.AlignHCenter
            }
          }
        }

        Grid {
          columns: 7
          columnSpacing: 0
          rowSpacing: 2
          width: parent.width

          Repeater {
            model: root.cells

            Item {
              width: 44
              height: 30

              property bool inMonth: modelData.inMonth
              property bool isToday: modelData.isToday
              property bool isSelected: modelData.isSelected
              property bool hasEvents: modelData.hasEvents

              Rectangle {
                anchors.fill: parent
                radius: 6
                color: isSelected ? Colors.surface_alt
                     : isToday ? Colors.primary
                     : mouseArea.containsMouse && inMonth ? Colors.surface_alt
                     : "transparent"
                border.color: isSelected ? Colors.primary : "transparent"
                border.width: 1
              }

              Text {
                anchors.centerIn: parent
                text: modelData.date.getDate()
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 12
                color: !inMonth ? Colors.muted
                     : isToday && !isSelected ? Colors.base
                     : isSelected ? Colors.text
                     : mouseArea.containsMouse ? Colors.text
                     : Colors.text_alt
              }

              Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 3
                width: 3
                height: 3
                radius: 1.5
                visible: hasEvents && !isToday
                color: isSelected ? Colors.primary : Colors.primary
              }

              MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.selectedDay = modelData.date
                  root.buildCells()
                }
              }
            }
          }
        }

        Rectangle {
          width: parent.width
          height: 1
          color: Colors.border
        }

        Text {
          width: parent.width
          text: root.selectedTitle()
          font.family: "JetBrainsMono Nerd Font Propo"
          font.pixelSize: 12
          font.weight: Font.DemiBold
          color: Colors.text
        }

        Repeater {
          model: root.dayEvents(root.selectedDay).slice(0, 6)

          Row {
            width: parent.width
            height: 22
            spacing: 10

            Text {
              width: 112
              anchors.verticalCenter: parent.verticalCenter
              text: root.eventTime(modelData)
              font.family: "JetBrainsMono Nerd Font Propo"
              font.pixelSize: 11
              color: modelData.a ? Colors.primary : Colors.muted
              elide: Text.ElideRight
            }

            Item {
              id: titleClip
              width: parent.width - 122
              height: parent.height
              clip: true

              property string titleText: modelData.t
              property bool overflowing: titleTextElide.implicitWidth > titleClip.width
              property bool marquee: false

              Text {
                id: titleTextElide
                width: titleClip.width
                anchors.verticalCenter: parent.verticalCenter
                visible: !titleClip.marquee
                text: titleClip.titleText
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 12
                color: Colors.text_alt
                elide: Text.ElideRight
              }

              Text {
                id: titleMarquee
                visible: titleClip.marquee
                y: titleClip.height / 2 - height / 2
                x: titleClip.width
                text: titleClip.titleText
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 12
                color: Colors.text_alt
              }

              property real titleMarqueeX: -titleMarquee.implicitWidth
              property int animDur: Math.max(1000, titleMarquee.implicitWidth * 12)
              property bool _first: true

              MouseArea {
                id: titleHover
                anchors.fill: parent
                hoverEnabled: true
                onEntered: {
                  if (titleClip.overflowing && !titleClip.marquee) {
                    titleClip.marquee = true
                    titleMarquee.x = titleClip.width
                    marqueeAnim.restart()
                  }
                }
                onExited: {
                  titleClip.marquee = false
                  marqueeAnim.stop()
                  titleMarquee.x = titleClip.width
                }
              }

              NumberAnimation {
                id: marqueeAnim
                target: titleMarquee
                property: "x"
                from: titleClip.width
                to: titleClip.titleMarqueeX
                duration: titleClip.animDur
                easing.type: Easing.Linear
              }
            }
          }
        }

        Text {
          width: parent.width
          visible: root.dayEvents(root.selectedDay).length === 0
          text: "No events"
          font.family: "JetBrainsMono Nerd Font Propo"
          font.pixelSize: 12
          color: Colors.muted
          horizontalAlignment: Text.AlignHCenter
        }

        Text {
          width: parent.width
          visible: root.dayEvents(root.selectedDay).length > 6
          text: "+ " + (root.dayEvents(root.selectedDay).length - 6) + " more"
          font.family: "JetBrainsMono Nerd Font Propo"
          font.pixelSize: 11
          color: Colors.muted
        }

        Row {
          width: parent.width
          spacing: 8

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.syncText
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 10
            color: Colors.muted
            elide: Text.ElideRight
          }

          Item {
            width: 1
            height: 1
          }

          Rectangle {
            id: syncBtn
            width: 56
            height: 22
            radius: 8
            color: syncMouse.containsMouse ? Colors.surface_alt : Colors.border
            Text {
              anchors.centerIn: parent
              text: root.loading ? "\uf013" : "\uf021"
              font.family: "JetBrainsMono Nerd Font Propo"
              font.pixelSize: 12
              color: Colors.text
            }
            MouseArea {
              id: syncMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.syncNow()
            }
          }
        }
      }
    }
  }
}
