import QtQuick
import Quickshell.Io
import qs
import "../components"

// Centered dashboard using the same live values as the topbar monitor.
LauncherBase {
  id: root

  sockName: "kmdot-sysmon"
  castStyle: true
  title: "System Monitor"
  headerTitle: "System Monitor"
  headerText: "System Monitor"
  searchPlaceholder: "Filter processes…"
  headerGlyph: "\uf080"
  searchEnabled: false
  clearQueryOnEscape: true
  property bool filterMode: false
  property real filterProgress: root.filterMode ? 1 : 0
  Behavior on filterProgress {
    NumberAnimation {
      duration: Tokens.reducedMotion ? 0 : 320
      easing.type: Easing.InOutCubic
    }
  }
  escapeKeyHandler: function() {
    if (root.pendingKillConfirmation) {
      root.pendingKillConfirmation = false
      root.pendingKillProcess = null
      return true
    }
    if (!root.filterMode) return false
    root.resetQuery()
    root.filterMode = false
    root.searchEnabled = false
    root.clearProcessSelection()
    Qt.callLater(function() {
      if (root.opened && root.viewNav) root.viewNav.forceActiveFocus()
    })
    return true
  }
  bareKeyCallbacks: [{
    key: Qt.Key_Slash,
    run: function() {
      root.filterMode = true
      root.searchEnabled = true
      root.clearProcessSelection()
      Qt.callLater(function() {
        if (root.viewInput) root.viewInput.forceActiveFocus()
      })
    }
  }]
  deactivatable: false
  cardHeight: SystemStatsState.threadPercents.length > 8 ? 565 : 520
  footerHint: "live values · refreshes every 3s"
  footerActionText: SystemStatsState.anyEnabled ? "Topbar on" : "Topbar off"
  footerActionGlyph: "\uf080"
  footerActionActive: SystemStatsState.anyEnabled
  closeHint: "Esc close"
  bodyFooterActions: root.filterMode ? [
    { label: "Navigate", keys: "↑ ↓" },
    { label: "Stop", keys: "Del" }
  ] : [
    { label: "Filter", keys: "/" }
  ]

  property var processes: []
  property string processSort: "cpu"
  readonly property var visibleProcesses: {
    const query = root.query.trim().toLowerCase()
    if (!query) return root.filterMode ? root.processes : root.processes.slice(0, 4)
    return root.processes.filter(process => process.name.toLowerCase().includes(query))
  }
  property bool pendingProcessRefresh: false
  property bool processSelectionActive: false
  property int selectedProcessPid: 0
  property bool pendingKillConfirmation: false
  property bool killInProgress: false
  property var pendingKillProcess: null
  property var killTarget: null
  property string killNotice: ""
  property var processSelectionSyncHandler: null
  property var cpuHistory: []
  property var memoryHistory: []
  items: []

  function appendHistory(values, percent) {
    if (percent < 0) return values
    const next = values.slice()
    next.push(percent)
    if (next.length > 30) next.shift()
    return next
  }

  function sampleHistory() {
    root.cpuHistory = root.appendHistory(root.cpuHistory, SystemStatsState.cpuPercent)
    root.memoryHistory = root.appendHistory(root.memoryHistory, SystemStatsState.memPercent)
  }

  function drawTrend(canvas, values, hot) {
    const ctx = canvas.getContext("2d")
    ctx.clearRect(0, 0, canvas.width, canvas.height)
    if (values.length === 0) return

    const inset = 5
    const plotWidth = Math.max(1, canvas.width - inset * 2)
    const plotHeight = Math.max(1, canvas.height - inset * 2)
    const xAt = i => values.length < 2
      ? inset + plotWidth
      : inset + plotWidth * i / (values.length - 1)
    const yAt = value => inset + plotHeight * (1 - Math.max(0, Math.min(100, value)) / 100)

    ctx.beginPath()
    for (let i = 0; i < values.length; i++) {
      const x = xAt(i)
      const y = yAt(values[i])
      if (i === 0) ctx.moveTo(x, y)
      else ctx.lineTo(x, y)
    }
    ctx.lineWidth = 2
    ctx.lineJoin = "round"
    ctx.lineCap = "round"
    ctx.strokeStyle = hot ? Colors.warning : Colors.primary
    ctx.stroke()

    ctx.beginPath()
    ctx.arc(xAt(values.length - 1), yAt(values[values.length - 1]), 3, 0, Math.PI * 2)
    ctx.fillStyle = hot ? Colors.warning : Colors.primary
    ctx.fill()
  }

  function refreshProcesses() {
    if (!root.opened) return
    if (topProc.running) {
      root.pendingProcessRefresh = true
      return
    }
    topProc.exec(["bash", SystemStatsState.scriptsDir + "/top-processes.sh", root.processSort])
  }

  function applyProcesses(text) {
    const rows = []
    String(text).trim().split("\n").forEach(line => {
      const parts = line.split("\t")
      if (parts.length < 4) return
      rows.push({
        cpu: parseFloat(parts[0]) || 0,
        mem: parseFloat(parts[1]) || 0,
        pid: parseInt(parts[2], 10) || 0,
        name: parts.slice(3).join(" ").trim()
      })
    })
    root.processes = rows
    Qt.callLater(function() {
      if (root.opened && root.processSelectionSyncHandler)
        root.processSelectionSyncHandler()
    })
  }

  function setTopbarEnabled(value) {
    SystemStatsState.setCpuEnabled(value)
    SystemStatsState.setMemEnabled(value)
  }

  function setProcessSort(sort) {
    if (root.processSort === sort) return
    root.clearProcessSelection()
    root.processSort = sort
    root.refreshProcesses()
  }

  function clearProcessSelection() {
    root.processSelectionActive = false
    root.selectedProcessPid = 0
    root.pendingKillConfirmation = false
    root.pendingKillProcess = null
  }

  function onOpenedChange() {
    SystemStatsState.keepPolling = root.opened
    if (root.opened) {
      root.filterMode = false
      root.searchEnabled = false
      root.clearProcessSelection()
      root.killNotice = ""
      root.cpuHistory = []
      root.memoryHistory = []
      root.sampleHistory()
      root.refreshProcesses()
    }
    else {
      root.processes = []
      root.pendingProcessRefresh = false
      root.clearProcessSelection()
    }
  }

  bodyContent: Component {
    Item {
      id: dashboard
      anchors.fill: parent
      property real gap: 10
      property int coreCount: SystemStatsState.threadPercents.length
      property int coreColumns: 8
      property int coreTileHeight: 37
      property int coreRows: Math.ceil(coreCount / coreColumns)
      property int coreGap: 6

      Component.onCompleted: {
        root.processSelectionSyncHandler = function() {
          if (!root.processSelectionActive) return
          const index = root.visibleProcesses.findIndex(process => process.pid === root.selectedProcessPid)
          if (index < 0) {
            root.clearProcessSelection()
            return
          }
          processList.currentIndex = index
          processList.positionViewAtIndex(index, ListView.Contain)
          if (root.pendingKillConfirmation && root.pendingKillProcess) {
            const stillRunning = root.processes.some(process => process.pid === root.pendingKillProcess.pid)
            if (!stillRunning) {
              root.pendingKillConfirmation = false
              root.pendingKillProcess = null
              root.killNotice = "PROCESS NO LONGER AVAILABLE"
              processNoticeTimer.restart()
            }
          }
        }
        root.searchNavigationHandler = function(delta) {
          if (!root.filterMode || root.visibleProcesses.length === 0) return false
          if (root.pendingKillConfirmation) return true
          const next = root.processSelectionActive
            ? Math.max(0, Math.min(root.visibleProcesses.length - 1, processList.currentIndex + delta))
            : (delta > 0 ? 0 : root.visibleProcesses.length - 1)
          root.processSelectionActive = true
          processList.currentIndex = next
          root.selectedProcessPid = root.visibleProcesses[next].pid
          processList.positionViewAtIndex(next, ListView.Contain)
          return true
        }
        root.searchKeyHandler = function(event) {
          if (event.key !== Qt.Key_Delete || !root.filterMode) return false
          if (root.killInProgress) return true
          if (root.pendingKillConfirmation) {
            const target = root.pendingKillProcess
            root.pendingKillConfirmation = false
            root.pendingKillProcess = null
            if (!target || target.pid <= 0) {
              root.killNotice = "PROCESS NO LONGER AVAILABLE"
              processNoticeTimer.restart()
              return true
            }
            root.killTarget = target
            root.killInProgress = true
            killProc.exec(["kill", "-TERM", String(target.pid)])
            return true
          }
          if (!root.processSelectionActive || processList.currentIndex < 0
              || processList.currentIndex >= root.visibleProcesses.length) return false
          root.pendingKillProcess = root.visibleProcesses[processList.currentIndex]
          root.pendingKillConfirmation = true
          return true
        }
      }
      Component.onDestruction: {
        root.processSelectionSyncHandler = null
        root.searchNavigationHandler = null
        root.searchKeyHandler = null
      }

      Column {
        id: dashboardColumn
        anchors.fill: parent
        spacing: dashboard.gap * (1 - root.filterProgress)

        Row {
          id: summaryRow
          width: parent.width
          height: 140 * (1 - root.filterProgress)
          opacity: 1 - root.filterProgress
          clip: true
          spacing: dashboard.gap

          Rectangle {
            id: cpuCard
            width: (parent.width - parent.spacing) / 2
            height: parent.height
            radius: 14
            color: Colors.surface_high
            border.width: 1
            border.color: Colors.outline_variant

            Column {
              anchors.fill: parent
              anchors.margins: 12
              spacing: 4

              Row {
                spacing: 8
                R1Icon {
                  anchors.verticalCenter: parent.verticalCenter
                  iconName: "cpu"
                  font.family: "JetBrainsMono Nerd Font Propo"
                  font.pixelSize: 17
                  color: SystemStatsState.cpuHot ? Colors.warning : Colors.text_alt
                }
                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: "CPU"
                  font.family: "JetBrainsMono Nerd Font"
                  font.pixelSize: 13
                  font.weight: Font.DemiBold
                  color: Colors.text_alt
                }
              }

              Row {
                width: parent.width
                height: 64
                spacing: 8

                Row {
                  width: 88
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: 3
                  Text {
                    id: cpuValue
                    text: SystemStatsState.cpuPercent < 0 ? "--" : SystemStatsState.cpuPercent.toString()
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 36
                    font.weight: Font.DemiBold
                    color: SystemStatsState.cpuHot ? Colors.warning : Colors.text
                  }
                  Text {
                    anchors.baseline: cpuValue.baseline
                    text: "%"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 18
                    color: Colors.text_alt
                  }
                }

                Item {
                  width: parent.width - 96
                  height: 58
                  anchors.verticalCenter: parent.verticalCenter
                  Rectangle { anchors.fill: parent; radius: 8; color: Colors.surface_alt }
                  Canvas {
                    id: cpuTrend
                    anchors.fill: parent
                    anchors.margins: 4
                    onPaint: root.drawTrend(cpuTrend, root.cpuHistory, SystemStatsState.cpuHot)
                  }
                }
              }

              Text {
                width: parent.width
                text: (SystemStatsState.cpuTemp >= 0 ? "" + SystemStatsState.cpuTempText + "  ·  " : "")
                  + "Load " + SystemStatsState.loadText
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 10
                color: Colors.text_alt
                elide: Text.ElideRight
              }
            }
          }

          Rectangle {
            id: memoryCard
            width: (parent.width - parent.spacing) / 2
            height: parent.height
            radius: 14
            color: Colors.surface_high
            border.width: 1
            border.color: Colors.outline_variant

            Column {
              anchors.fill: parent
              anchors.margins: 12
              spacing: 4

              Row {
                spacing: 8
                R1Icon {
                  anchors.verticalCenter: parent.verticalCenter
                  iconName: "memory"
                  font.family: "JetBrainsMono Nerd Font Propo"
                  font.pixelSize: 17
                  color: SystemStatsState.memHot ? Colors.warning : Colors.text_alt
                }
                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: "MEMORY"
                  font.family: "JetBrainsMono Nerd Font"
                  font.pixelSize: 13
                  font.weight: Font.DemiBold
                  color: Colors.text_alt
                }
              }

              Row {
                width: parent.width
                height: 64
                spacing: 8

                Row {
                  width: 88
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: 3
                  Text {
                    id: memValue
                    text: SystemStatsState.memPercent < 0 ? "--" : SystemStatsState.memPercent.toString()
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 36
                    font.weight: Font.DemiBold
                    color: SystemStatsState.memHot ? Colors.warning : Colors.text
                  }
                  Text {
                    anchors.baseline: memValue.baseline
                    text: "%"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 18
                    color: Colors.text_alt
                  }
                }

                Item {
                  width: parent.width - 96
                  height: 58
                  anchors.verticalCenter: parent.verticalCenter
                  Rectangle { anchors.fill: parent; radius: 8; color: Colors.surface_alt }
                  Canvas {
                    id: memoryTrend
                    anchors.fill: parent
                    anchors.margins: 4
                    onPaint: root.drawTrend(memoryTrend, root.memoryHistory, SystemStatsState.memHot)
                  }
                }
              }

              Text {
                width: parent.width
                text: SystemStatsState.memUsedGb + " / " + SystemStatsState.memTotalGb
                  + " GB used  ·  " + SystemStatsState.memFreeGb + " GB available"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 10
                color: Colors.text_alt
                elide: Text.ElideRight
              }
            }
          }
        }

        Rectangle {
          id: coresCard
          width: parent.width
          height: (coreFlow.height + 54) * (1 - root.filterProgress)
          opacity: 1 - root.filterProgress
          clip: true
          radius: 14
          color: Colors.surface_high
          border.width: 1
          border.color: Colors.outline_variant

          Text {
            anchors { left: parent.left; top: parent.top; leftMargin: 14; topMargin: 12 }
            text: "CPU CORES"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 11
            font.weight: Font.DemiBold
            font.letterSpacing: 0.6
            color: Colors.text_alt
          }

          Flow {
            id: coreFlow
            anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 14; rightMargin: 14; topMargin: 36 }
            height: dashboard.coreRows > 0
              ? dashboard.coreRows * dashboard.coreTileHeight + (dashboard.coreRows - 1) * dashboard.coreGap
              : 0
            spacing: 6
            Repeater {
              model: dashboard.coreCount
              delegate: Rectangle {
                required property int index
                width: Math.max(54, Math.floor((coreFlow.width - (dashboard.coreColumns - 1) * dashboard.coreGap) / dashboard.coreColumns))
                height: dashboard.coreTileHeight
                radius: 7
                color: Colors.surface_alt

                Column {
                  anchors.fill: parent
                  anchors.margins: 6
                  spacing: 3
                  Row {
                    width: parent.width
                    Text {
                      width: 28
                      text: "C" + index
                      font.family: "JetBrainsMono Nerd Font"
                      font.pixelSize: 10
                      color: Colors.text_alt
                    }
                    Item { width: parent.width - 28 - coreValue.implicitWidth; height: 1 }
                    Text {
                      id: coreValue
                      text: SystemStatsState.threadPercents[index] + "%"
                      font.family: "JetBrainsMono Nerd Font"
                      font.pixelSize: 10
                      font.weight: Font.DemiBold
                      color: SystemStatsState.threadPercents[index] >= 85 ? Colors.warning : Colors.text
                    }
                  }
                  Rectangle {
                    width: parent.width
                    height: 4
                    radius: 2
                    color: Colors.surface
                    Rectangle {
                      width: parent.width * Math.max(0, Math.min(1, SystemStatsState.threadPercents[index] / 100))
                      height: parent.height
                      radius: parent.radius
                      color: SystemStatsState.threadPercents[index] >= 85 ? Colors.warning : Colors.primary
                    }
                  }
                }
              }
            }
          }
        }

        Rectangle {
          id: processesCard
          width: parent.width
          height: root.filterMode
            ? Math.max(148, dashboard.height - summaryRow.height - coresCard.height - dashboardColumn.spacing * 2)
            : 148
          radius: 14
          color: Colors.surface_high
          border.width: 1
          border.color: Colors.outline_variant

          Column {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 6

            Row {
              width: parent.width - 16
              anchors.horizontalCenter: parent.horizontalCenter
              Text {
                id: processHeading
                text: root.pendingKillConfirmation ? "STOP PROCESS?"
                  : root.killNotice !== "" ? root.killNotice
                  : root.filterMode ? "PROCESSES · " + root.visibleProcesses.length
                  : "TOP PROCESSES"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
                font.weight: Font.DemiBold
                font.letterSpacing: 0.6
                color: root.pendingKillConfirmation ? Colors.warning : Colors.text_alt
              }
              Item {
                width: parent.width - processHeading.implicitWidth
                  - (root.pendingKillConfirmation ? killConfirmHint.implicitWidth
                    : root.killNotice !== "" ? 0 : processLegend.implicitWidth)
                height: 1
              }
              Text {
                id: killConfirmHint
                visible: root.pendingKillConfirmation
                text: "Delete again · Esc cancel"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 10
                color: Colors.warning
              }
              Row {
                id: processLegend
                visible: !root.pendingKillConfirmation && root.killNotice === ""
                width: 77
                spacing: 1
                Text {
                  width: 38
                  text: "CPU"
                  horizontalAlignment: Text.AlignRight
                  font.family: "JetBrainsMono Nerd Font"
                  font.pixelSize: 10
                  font.weight: root.processSort === "cpu" ? Font.DemiBold : Font.Normal
                  color: root.processSort === "cpu" ? Colors.primary : Colors.text_alt
                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.setProcessSort("cpu")
                  }
                }
                Text {
                  width: 38
                  text: "RAM"
                  horizontalAlignment: Text.AlignRight
                  font.family: "JetBrainsMono Nerd Font"
                  font.pixelSize: 10
                  font.weight: root.processSort === "mem" ? Font.DemiBold : Font.Normal
                  color: root.processSort === "mem" ? Colors.primary : Colors.text_alt
                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.setProcessSort("mem")
                  }
                }
              }
            }

            Item {
              id: processArea
              width: parent.width
              height: root.filterMode ? Math.max(104, processesCard.height - 43) : 104

            ListView {
              id: processList
              anchors.fill: parent
              clip: true
              model: root.visibleProcesses
              spacing: 6
              currentIndex: 0
              boundsBehavior: Flickable.StopAtBounds
              delegate: Item {
                required property int index
                required property var modelData
                readonly property var process: modelData
                readonly property bool selected: ListView.isCurrentItem
                width: parent.width
                height: 20
                Rectangle {
                  anchors { fill: parent; topMargin: 1; bottomMargin: 1 }
                  visible: root.filterMode && root.processSelectionActive && selected
                  radius: 8
                  color: Colors.primary_container
                }
                TapHandler {
                  enabled: root.filterMode
                  onTapped: {
                    root.clearProcessSelection()
                    root.processSelectionActive = true
                    processList.currentIndex = index
                    root.selectedProcessPid = process.pid
                  }
                }
                Row {
                  anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                  spacing: 8
                  Text {
                    width: 135
                    anchors.verticalCenter: parent.verticalCenter
                    text: process ? process.name : ""
                    elide: Text.ElideRight
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    color: root.processSelectionActive && selected ? Colors.on_primary_container : Colors.text
                  }
                  Rectangle {
                    width: Math.max(40, parent.width - 235)
                    height: 5
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 3
                    color: Colors.surface_alt
                    Rectangle {
                      readonly property real metricPercent: process
                        ? (root.processSort === "cpu" ? process.cpu : process.mem) : 0
                      width: parent.width * Math.max(0, Math.min(1, metricPercent / 100))
                      height: parent.height
                      radius: parent.radius
                      color: Colors.primary
                    }
                  }
                  Text {
                    width: 38
                    anchors.verticalCenter: parent.verticalCenter
                    text: process ? process.cpu.toFixed(1) + "%" : ""
                    horizontalAlignment: Text.AlignRight
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 10
                    color: root.processSelectionActive && selected ? Colors.on_primary_container : Colors.text_alt
                  }
                  Text {
                    width: 38
                    anchors.verticalCenter: parent.verticalCenter
                    text: process ? process.mem.toFixed(1) + "%" : ""
                    horizontalAlignment: Text.AlignRight
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 10
                    color: root.processSelectionActive && selected ? Colors.on_primary_container : Colors.text_alt
                  }
                }
              }
            }

            Text {
              anchors.fill: parent
              visible: root.processes.length === 0 || (root.query.trim() !== "" && root.visibleProcesses.length === 0)
              verticalAlignment: Text.AlignVCenter
              horizontalAlignment: Text.AlignHCenter
              text: root.processes.length === 0 ? "Collecting process usage…" : "No matching processes"
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 12
              color: Colors.text_alt
            }
            }
          }
        }
      }
      Connections {
        target: root
        function onCpuHistoryChanged() { cpuTrend.requestPaint() }
        function onMemoryHistoryChanged() { memoryTrend.requestPaint() }
        function onQueryChanged() {
          root.clearProcessSelection()
          processList.currentIndex = 0
          processList.contentY = 0
        }
      }
    }
  }

  Timer {
    interval: 3000
    repeat: true
    running: root.opened
    onTriggered: root.refreshProcesses()
  }

  Timer {
    interval: 2000
    repeat: true
    running: root.opened
    onTriggered: root.sampleHistory()
  }

  Process {
    id: topProc
    stdout: StdioCollector {
      onStreamFinished: root.applyProcesses(String(this.text))
    }
    onExited: {
      if (root.pendingProcessRefresh) {
        root.pendingProcessRefresh = false
        root.refreshProcesses()
      }
    }
  }

  Process {
    id: killProc
    onExited: function(code) {
      root.killInProgress = false
      root.killNotice = code === 0 ? "SIGTERM SENT" : "STOP FAILED"
      root.killTarget = null
      processNoticeTimer.restart()
      if (code === 0) postKillRefreshTimer.restart()
    }
  }

  Timer {
    id: processNoticeTimer
    interval: 2500
    repeat: false
    onTriggered: root.killNotice = ""
  }

  Timer {
    id: postKillRefreshTimer
    interval: 700
    repeat: false
    onTriggered: root.refreshProcesses()
  }

  onFooterActionClicked: root.setTopbarEnabled(!SystemStatsState.anyEnabled)
}
