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
  headerGlyph: "\uf080"
  searchEnabled: false
  deactivatable: false
  cardHeight: SystemStatsState.threadPercents.length > 8 ? 565 : 520
  footerHint: "live values · refreshes every 3s"
  footerActionText: SystemStatsState.anyEnabled ? "Topbar on" : "Topbar off"
  footerActionGlyph: "\uf080"
  footerActionActive: SystemStatsState.anyEnabled
  closeHint: "Esc close"

  property var processes: []
  property bool pendingProcessRefresh: false
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
    topProc.exec(["bash", SystemStatsState.scriptsDir + "/top-processes.sh", "cpu"])
  }

  function applyProcesses(text) {
    const rows = []
    String(text).trim().split("\n").forEach(line => {
      const parts = line.split("\t")
      if (parts.length < 3) return
      rows.push({
        cpu: parseFloat(parts[0]) || 0,
        mem: parseFloat(parts[1]) || 0,
        name: parts.slice(2).join(" ").trim()
      })
    })
    root.processes = rows
  }

  function setTopbarEnabled(value) {
    SystemStatsState.setCpuEnabled(value)
    SystemStatsState.setMemEnabled(value)
  }

  function onOpenedChange() {
    SystemStatsState.keepPolling = root.opened
    if (root.opened) {
      root.cpuHistory = []
      root.memoryHistory = []
      root.sampleHistory()
      root.refreshProcesses()
    }
    else {
      root.processes = []
      root.pendingProcessRefresh = false
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

      Column {
        anchors.fill: parent
        spacing: dashboard.gap

        Row {
          id: summaryRow
          width: parent.width
          height: 140
          spacing: dashboard.gap

          Rectangle {
            id: cpuCard
            width: (parent.width - parent.spacing) / 2
            height: parent.height
            radius: 14
            color: Colors.surface_alt

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
                  Rectangle { anchors.fill: parent; radius: 8; color: Colors.surface_high }
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
            color: Colors.surface_alt

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
                  Rectangle { anchors.fill: parent; radius: 8; color: Colors.surface_high }
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
          height: coreFlow.height + 54
          radius: 14
          color: Colors.surface_alt

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
                color: Colors.surface_high

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
          height: 148
          radius: 14
          color: Colors.surface_alt

          Column {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 6

            Row {
              width: parent.width
              Text {
                id: processHeading
                text: "TOP PROCESSES"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
                font.weight: Font.DemiBold
                font.letterSpacing: 0.6
                color: Colors.text_alt
              }
              Item { width: parent.width - processHeading.implicitWidth - processLegend.implicitWidth; height: 1 }
              Text {
                id: processLegend
                text: "CPU  ·  RAM"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 10
                color: Colors.text_alt
              }
            }

            Repeater {
              model: Math.min(4, root.processes.length)
              delegate: Row {
                required property int index
                readonly property var process: root.processes[index]
                width: parent.width
                height: 20
                spacing: 8
                Text {
                  width: 135
                  anchors.verticalCenter: parent.verticalCenter
                  text: process ? process.name : ""
                  elide: Text.ElideRight
                  font.family: "JetBrainsMono Nerd Font"
                  font.pixelSize: 11
                  color: Colors.text
                }
                Rectangle {
                  width: Math.max(40, parent.width - 220)
                  height: 5
                  anchors.verticalCenter: parent.verticalCenter
                  radius: 3
                  color: Colors.surface_high
                  Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, process ? process.cpu / 100 : 0))
                    height: parent.height
                    radius: parent.radius
                    color: Colors.primary
                  }
                }
                Text {
                  width: 65
                  anchors.verticalCenter: parent.verticalCenter
                  text: process ? process.cpu.toFixed(1) + "% · " + process.mem.toFixed(1) + "%" : ""
                  horizontalAlignment: Text.AlignRight
                  font.family: "JetBrainsMono Nerd Font"
                  font.pixelSize: 10
                  color: Colors.text_alt
                }
              }
            }

            Text {
              visible: root.processes.length === 0
              width: parent.width
              height: visible ? 80 : 0
              verticalAlignment: Text.AlignVCenter
              horizontalAlignment: Text.AlignHCenter
              text: "Collecting process usage…"
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 12
              color: Colors.text_alt
            }
          }
        }
      }
      Connections {
        target: root
        function onCpuHistoryChanged() { cpuTrend.requestPaint() }
        function onMemoryHistoryChanged() { memoryTrend.requestPaint() }
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

  onFooterActionClicked: root.setTopbarEnabled(!SystemStatsState.anyEnabled)
}
