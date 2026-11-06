import QtQuick
import Quickshell
import Quickshell.Io
import qs
import "../components"

// System Monitor card: live CPU/memory detail, the bar-visibility toggles, and
// a short top-process list for comparing applications. The process list only
// polls while this card is open.
PopupBase {
  id: root

  sockName: "kmdot-sysmon"
  title: "System Monitor"
  cardWidth: 424
  cardRadius: 20
  cardBorderWidth: 1
  cardBorderColor: Colors.outline_variant

  property string processMode: "cpu"
  property var processes: []
  property bool pendingRefresh: false
  // Must match the row count emitted by scripts/top-processes.sh.
  readonly property int processRowCount: 6
  readonly property int processRowHeight: 24
  readonly property int processRowSpacing: 6

  function refreshItems() {
    SystemStatsState.refresh()
    root.refreshProcesses()
  }

  function openedChange() {
    SystemStatsState.keepPolling = root.opened
    if (!root.opened) {
      root.processes = []
      root.pendingRefresh = false
    }
  }

  function setProcessMode(mode) {
    if (root.processMode === mode) return
    root.processMode = mode
    root.processes = []
    root.refreshProcesses()
  }

  function refreshProcesses() {
    if (topProc.running) {
      root.pendingRefresh = true
      return
    }
    topProc.exec(["bash", SystemStatsState.scriptsDir + "/top-processes.sh", root.processMode])
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

  Timer {
    id: processTimer
    interval: 3000
    repeat: true
    running: root.opened
    onTriggered: root.refreshProcesses()
  }

  Process {
    id: topProc
    stdout: StdioCollector {
      onStreamFinished: root.applyProcesses(String(this.text))
    }
    onExited: {
      if (root.pendingRefresh) {
        root.pendingRefresh = false
        root.refreshProcesses()
      }
    }
  }

  // ---- header ----
  Row {
    width: parent.width
    height: 32
    spacing: 12

    R1Icon {
      width: 24
      height: 24
      anchors.verticalCenter: parent.verticalCenter
      iconName: "chart"
      font.pixelSize: 22
      color: Colors.text
    }

    Text {
      id: popupTitle
      anchors.verticalCenter: parent.verticalCenter
      text: "System Monitor"
      font.family: "JetBrainsMono Nerd Font"
      font.pixelSize: 23
      font.weight: Font.DemiBold
      color: Colors.text
    }

    Item {
      width: Math.max(0, parent.width - 36 - popupTitle.implicitWidth - 40)
      height: 1
    }
  }

  // ---- CPU ----
  Column {
    width: parent.width
    spacing: 6

    Item {
      width: parent.width
      height: Math.max(cpuLabel.implicitHeight, cpuStats.implicitHeight)

      Text {
        id: cpuLabel
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: "CPU"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 12
        color: Colors.text_alt
      }

      // Temp and usage are laid out as a tight group and right-aligned
      // together: fixed-width columns left a visible gap that grew/shrunk with
      // the number of digits.
      Row {
        id: cpuStats
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Text {
          id: cpuTempValue
          visible: SystemStatsState.cpuTemp >= 0
          text: SystemStatsState.cpuTempText
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 13
          color: SystemStatsState.cpuTemp >= SystemStatsState.tempCritical ? Colors.error
            : SystemStatsState.cpuTemp >= SystemStatsState.tempWarn ? Colors.warning
            : Colors.text_alt
        }

        Text {
          text: SystemStatsState.cpuText
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 14
          color: SystemStatsState.cpuHot ? Colors.warning : Colors.text
        }
      }
    }

    Rectangle {
      width: parent.width
      height: 8
      radius: 4
      color: Colors.surface_alt

      Rectangle {
        width: parent.width * Math.max(0, SystemStatsState.cpuPercent) / 100
        height: parent.height
        radius: parent.radius
        color: SystemStatsState.cpuHot ? Colors.warning : Colors.primary
        Behavior on width {
          NumberAnimation { duration: Tokens.meterMotion; easing.type: Tokens.motionEasing }
        }
      }
    }

    Text {
      text: SystemStatsState.loadText === "" ? "" : "Load " + SystemStatsState.loadText
      font.family: "JetBrainsMono Nerd Font"
      font.pixelSize: 11
      color: Tokens.mutedText
    }
  }

  // ---- per-thread CPU ----
  Column {
    visible: SystemStatsState.threadPercents.length > 0
    width: parent.width
    spacing: 8

    Text {
      text: "THREADS"
      font.family: "JetBrainsMono Nerd Font"
      font.pixelSize: 12
      color: Colors.text_alt
    }

    Grid {
      id: threadGrid
      width: parent.width
      columns: 2
      rowSpacing: 4
      columnSpacing: 12

      Repeater {
        model: SystemStatsState.threadPercents.length

        delegate: Item {
          required property int index
          readonly property int percent: index < SystemStatsState.threadPercents.length
            ? SystemStatsState.threadPercents[index] : 0
          readonly property int temp: SystemStatsState.threadTemp(index)

          width: (threadGrid.width - threadGrid.columnSpacing) / 2
          height: 18

          Text {
            id: threadLabel
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            text: "cpu" + index
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 10
            color: Tokens.mutedText
          }

          Rectangle {
            anchors.left: threadLabel.right
            anchors.right: threadValue.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            height: 6
            radius: 3
            color: Colors.surface_alt

            Rectangle {
              width: parent.width * percent / 100
              height: parent.height
              radius: parent.radius
              color: percent >= 80 ? Colors.warning : Colors.primary
              Behavior on width {
                NumberAnimation { duration: Tokens.meterMotion; easing.type: Tokens.motionEasing }
              }
            }
          }

          Text {
            id: threadValue
            anchors.right: threadTempSlot.left
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            width: 30
            horizontalAlignment: Text.AlignRight
            text: percent + "%"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 10
            color: percent >= 80 ? Colors.warning : Colors.text_alt
          }

          Item {
            id: threadTempSlot
            width: SystemStatsState.threadTempsAvailable ? 40 : 0
            height: parent.height
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            Text {
              anchors.fill: parent
              horizontalAlignment: Text.AlignRight
              verticalAlignment: Text.AlignVCenter
              visible: SystemStatsState.threadTempsAvailable && temp >= 0
              text: temp >= 0 ? temp + "°C" : ""
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 10
              color: temp >= SystemStatsState.tempCritical ? Colors.error
                : temp >= SystemStatsState.tempWarn ? Colors.warning
                : Tokens.mutedText
            }
          }
        }
      }
    }
  }

  // ---- memory ----
  Column {
    width: parent.width
    spacing: 6

    Row {
      width: parent.width
      Text {
        id: memLabel
        text: "MEMORY"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 12
        color: Colors.text_alt
      }
      Item { width: Math.max(0, parent.width - memLabel.implicitWidth - 70); height: 1 }
      Text {
        width: 70
        horizontalAlignment: Text.AlignRight
        text: SystemStatsState.memText
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 14
        color: SystemStatsState.memHot ? Colors.warning : Colors.text
      }
    }

    Rectangle {
      width: parent.width
      height: 8
      radius: 4
      color: Colors.surface_alt

      Rectangle {
        width: parent.width * Math.max(0, SystemStatsState.memPercent) / 100
        height: parent.height
        radius: parent.radius
        color: SystemStatsState.memHot ? Colors.warning : Colors.primary
        Behavior on width {
          NumberAnimation { duration: Tokens.meterMotion; easing.type: Tokens.motionEasing }
        }
      }
    }

    Text {
      text: SystemStatsState.memTotalKb > 0
        ? SystemStatsState.memUsedGb + " / " + SystemStatsState.memTotalGb + " GB used · "
          + SystemStatsState.memFreeGb + " GB available"
        : ""
      font.family: "JetBrainsMono Nerd Font"
      font.pixelSize: 11
      color: Tokens.mutedText
    }
  }

  // ---- bar visibility ----
  Column {
    width: parent.width
    spacing: 8

    Text {
      text: "BAR WIDGETS"
      font.family: "JetBrainsMono Nerd Font"
      font.pixelSize: 12
      color: Colors.text_alt
    }

    Row {
      width: parent.width
      spacing: 8

      PillButton {
        width: (parent.width - 8) / 2
        height: 34
        buttonStyle: "action"
        inactiveFillColor: Colors.surface_alt
        active: SystemStatsState.cpuEnabled
        iconName: "cpu"
        text: "CPU"
        textSize: 13
        onClicked: SystemStatsState.setCpuEnabled(!SystemStatsState.cpuEnabled)
      }

      PillButton {
        width: (parent.width - 8) / 2
        height: 34
        buttonStyle: "action"
        inactiveFillColor: Colors.surface_alt
        active: SystemStatsState.memEnabled
        iconName: "memory"
        text: "Memory"
        textSize: 13
        onClicked: SystemStatsState.setMemEnabled(!SystemStatsState.memEnabled)
      }
    }
  }

  // ---- top processes ----
  Column {
    width: parent.width
    spacing: 6

    Text {
      text: "PROCESSES"
      font.family: "JetBrainsMono Nerd Font"
      font.pixelSize: 12
      color: Colors.text_alt
    }

    Row {
      id: processColumns
      width: parent.width
      height: 18

      Text {
        width: processColumns.width - 120
        anchors.verticalCenter: parent.verticalCenter
        text: "PROCESS"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 10
        color: Tokens.mutedText
      }

      // Column headers double as the sort control: no extra buttons needed.
      Item {
        id: cpuHeader
        width: 60
        height: parent.height
        readonly property bool sorted: root.processMode === "cpu"

        Row {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: 3

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "CPU"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 10
            font.weight: cpuHeader.sorted ? Font.DemiBold : Font.Normal
            color: cpuHeader.sorted ? Colors.primary
              : cpuHeaderMouse.containsMouse ? Colors.text : Tokens.mutedText
          }

          R1Icon {
            visible: cpuHeader.sorted
            anchors.verticalCenter: parent.verticalCenter
            iconName: "chevron-down"
            font.pixelSize: 10
            color: Colors.primary
          }
        }

        MouseArea {
          id: cpuHeaderMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.setProcessMode("cpu")
        }
      }

      Item {
        id: memHeader
        width: 60
        height: parent.height
        readonly property bool sorted: root.processMode === "mem"

        Row {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: 3

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "MEM"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 10
            font.weight: memHeader.sorted ? Font.DemiBold : Font.Normal
            color: memHeader.sorted ? Colors.primary
              : memHeaderMouse.containsMouse ? Colors.text : Tokens.mutedText
          }

          R1Icon {
            visible: memHeader.sorted
            anchors.verticalCenter: parent.verticalCenter
            iconName: "chevron-down"
            font.pixelSize: 10
            color: Colors.primary
          }
        }

        MouseArea {
          id: memHeaderMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.setProcessMode("mem")
        }
      }
    }

    Item {
      width: parent.width
      // Reserve the full list at all times so the card height does not jump
      // between the loading state and the first process sample.
      height: root.processRowCount * root.processRowHeight
        + (root.processRowCount - 1) * root.processRowSpacing

      Column {
        width: parent.width
        spacing: root.processRowSpacing

        Repeater {
          model: root.processes

          delegate: Item {
            required property var modelData
            required property int index

            width: parent.width
            height: root.processRowHeight

            Text {
              anchors.left: parent.left
              anchors.right: cpuValue.left
              anchors.rightMargin: 8
              anchors.verticalCenter: parent.verticalCenter
              text: modelData.name
              elide: Text.ElideRight
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 12
              color: Colors.text
            }

            Text {
              id: cpuValue
              anchors.right: memValue.left
              anchors.verticalCenter: parent.verticalCenter
              width: 60
              horizontalAlignment: Text.AlignRight
              text: modelData.cpu.toFixed(1) + "%"
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 12
              color: root.processMode === "cpu" ? Colors.primary : Colors.text_alt
            }

            Text {
              id: memValue
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              width: 60
              horizontalAlignment: Text.AlignRight
              text: modelData.mem.toFixed(1) + "%"
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 12
              color: root.processMode === "mem" ? Colors.primary : Colors.text_alt
            }
          }
        }
      }

      Text {
        visible: root.processes.length === 0
        anchors.top: parent.top
        text: "Reading processes…"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 12
        color: Tokens.mutedText
      }
    }
  }
}
