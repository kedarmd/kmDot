pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

// Single owner for bar-vitals state. One poll feeds every screen's bar, and the
// timer only runs while a vitals segment is enabled or the System Monitor card
// is open. Hiding both segments therefore stops all /proc reads and the script
// exec entirely. Poll cadence lives here, not in the view modules.
Singleton {
  id: root

  // Persisted bar visibility (same JsonAdapter pattern as DnDState).
  property bool cpuEnabled: true
  property bool memEnabled: true
  // Set by the System Monitor popup while it is open, so the card still shows
  // live values even when both bar segments are hidden.
  property bool keepPolling: false

  property int cpuPercent: -1
  property int memPercent: -1
  property real memUsedKb: 0
  property real memTotalKb: 0
  property string load1: ""
  property string load5: ""
  property string load15: ""
  // Logical CPU count from the main poll. Used to reserve the THREADS grid
  // before the first thread sample so the card height never jumps.
  property int threadCount: 0
  // Per-logical-CPU busy percentages, index = cpuN. Only sampled while the
  // System Monitor card is open.
  property var threadPercents: []

  readonly property bool anyEnabled: root.cpuEnabled || root.memEnabled
  readonly property bool polling: root.anyEnabled || root.keepPolling
  readonly property bool cpuHot: root.cpuPercent >= 80
  readonly property bool memHot: root.memPercent >= 85

  readonly property string cpuText: root.cpuPercent < 0 ? "--" : root.cpuPercent + "%"
  readonly property string memText: root.memPercent < 0 ? "--" : root.memPercent + "%"
  readonly property string memUsedGb: (root.memUsedKb / 1048576).toFixed(1)
  readonly property string memTotalGb: (root.memTotalKb / 1048576).toFixed(1)
  readonly property string memFreeGb: (Math.max(0, root.memTotalKb - root.memUsedKb) / 1048576).toFixed(1)
  readonly property string loadText: root.load1 === "" ? "" : root.load1 + " · " + root.load5 + " · " + root.load15

  readonly property string scriptsDir: Quickshell.env("HOME") + "/.config/kmdot/quickshell/scripts"

  function setCpuEnabled(value: bool) {
    if (root.cpuEnabled !== value) root.cpuEnabled = value
  }
  function setMemEnabled(value: bool) {
    if (root.memEnabled !== value) root.memEnabled = value
  }

  function refresh() {
    if (!statsProc.running) statsProc.running = true
  }

  function clampPercent(value) {
    if (!isFinite(value)) return -1
    return Math.max(0, Math.min(100, Math.round(value)))
  }

  function applyStats(text) {
    const out = {}
    String(text).trim().split("\n").forEach(line => {
      const eq = line.indexOf("=")
      if (eq > 0) out[line.slice(0, eq)] = line.slice(eq + 1)
    })
    if ("cpu" in out) root.cpuPercent = root.clampPercent(parseInt(out.cpu, 10))
    if ("mem_pct" in out) root.memPercent = root.clampPercent(parseInt(out.mem_pct, 10))
    if ("mem_used_kb" in out) root.memUsedKb = Math.max(0, parseInt(out.mem_used_kb, 10) || 0)
    if ("mem_total_kb" in out) root.memTotalKb = Math.max(0, parseInt(out.mem_total_kb, 10) || 0)
    if ("load1" in out) root.load1 = String(out.load1)
    if ("load5" in out) root.load5 = String(out.load5)
    if ("load15" in out) root.load15 = String(out.load15)
    if ("threads" in out) {
      const count = parseInt(out.threads, 10)
      if (count > 0 && count !== root.threadCount) {
        root.threadCount = count
        if (root.threadPercents.length !== count) {
          const zeros = []
          for (let i = 0; i < count; i++) zeros.push(0)
          root.threadPercents = zeros
        }
      }
    }
  }

  function applyThreads(text) {
    const rows = []
    String(text).trim().split("\n").forEach(line => {
      const eq = line.indexOf("=")
      if (eq < 1) return
      const match = /^cpu(\d+)$/.exec(line.slice(0, eq))
      if (!match) return
      rows.push({
        index: parseInt(match[1], 10),
        percent: root.clampPercent(parseInt(line.slice(eq + 1), 10))
      })
    })
    rows.sort((a, b) => a.index - b.index)
    root.threadPercents = rows.map(row => row.percent)
  }

  Timer {
    interval: 2000
    repeat: true
    running: root.polling
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Process {
    id: statsProc
    command: ["bash", root.scriptsDir + "/system-stats.sh"]
    stdout: StdioCollector {
      onStreamFinished: root.applyStats(String(this.text))
    }
  }

  // Thread detail is card-only: this timer runs exclusively while the popup
  // holds keepPolling, so a closed card costs nothing.
  Timer {
    interval: 1000
    repeat: true
    running: root.keepPolling
    triggeredOnStart: true
    onTriggered: {
      if (!threadProc.running) threadProc.running = true
    }
  }

  Process {
    id: threadProc
    command: ["bash", root.scriptsDir + "/thread-stats.sh"]
    stdout: StdioCollector {
      onStreamFinished: root.applyThreads(String(this.text))
    }
  }

  // ---- persisted bar visibility ----
  Timer {
    id: fileReloadTimer
    interval: 100
    repeat: false
    onTriggered: settingsFile.reload()
  }

  Timer {
    id: fileWriteTimer
    interval: 100
    repeat: false
    onTriggered: settingsFile.writeAdapter()
  }

  FileView {
    id: settingsFile
    path: Quickshell.statePath("bar-stats.json")
    watchChanges: true
    onFileChanged: fileReloadTimer.restart()
    onAdapterUpdated: fileWriteTimer.restart()
    onLoadFailed: error => {
      if (error === FileViewError.FileNotFound)
        fileWriteTimer.restart()
    }

    adapter: JsonAdapter {
      id: settings
      property bool cpuEnabled: true
      property bool memEnabled: true
    }
  }

  Connections {
    target: settings
    function onCpuEnabledChanged() { root.cpuEnabled = settings.cpuEnabled }
    function onMemEnabledChanged() { root.memEnabled = settings.memEnabled }
  }

  onCpuEnabledChanged: {
    if (settings.cpuEnabled !== root.cpuEnabled) settings.cpuEnabled = root.cpuEnabled
  }
  onMemEnabledChanged: {
    if (settings.memEnabled !== root.memEnabled) settings.memEnabled = root.memEnabled
  }
}
