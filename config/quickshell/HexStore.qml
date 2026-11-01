pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

// Single read/action boundary for the Hex launcher, popup, and HUD.
Singleton {
  id: root

  property var models: []
  property var history: []
  property string selectedModel: ""
  property string activityState: "unknown"
  property string deviceName: ""
  property string errorText: ""
  property string modelNote: ""
  property int copiedHistoryId: -1
  property string copyFeedback: ""
  property int pendingCopyId: -1
  property bool commandBusy: false
  property bool loading: false
  property bool modelSelectionAvailable: false
  property string lastAction: ""
  property int statusFailureCount: 0
  readonly property bool active: /record|transcrib|dictat|processing/i.test(root.activityState)
  readonly property string stateLabel: {
    const state = root.activityState.toLowerCase()
    if (/transcrib|processing/.test(state)) return "Transcribing"
    if (/record|dictat/.test(state)) return "Recording"
    if (/error|fail/.test(state)) return "Needs attention"
    if (/listen|ready|idle/.test(state)) return "Ready"
    return "Connecting to Hex"
  }

  function refresh() {
    root.loading = true
    root.requestStatus()
    if (!modelProc.running) modelProc.exec(["node", root.modelScript()])
    root.refreshHistory()
  }

  function requestStatus() {
    if (statusProc.running) return
    statusProc.outputText = ""
    statusProc.exec([
      "bash",
      Quickshell.env("HOME") + "/.config/kmdot/quickshell/scripts/hex-status.sh"
    ])
  }

  function refreshHistory() {
    if (!historyProc.running) historyProc.exec(["node", root.historyScript()])
  }

  function historyScript() {
    return Quickshell.env("HOME") + "/.config/kmdot/quickshell/scripts/hex-history.mjs"
  }
  function modelScript() {
    return Quickshell.env("HOME") + "/.config/kmdot/quickshell/scripts/hex-models.mjs"
  }

  function applyStatus(text) {
    try {
      const value = JSON.parse(String(text || ""))
      const activity = value && value.desktop ? value.desktop.activity : null
      if (activity) {
        // Hex 3.0 status JSON exposes the older desktop.activity shape.
        root.statusFailureCount = 0
        root.activityState = String(activity.state || "unknown")
        root.deviceName = String(activity.device || "")
        root.errorText = activity.error ? String(activity.error) : ""
        return
      }

      // Hex 3.1+ uses a versioned JSON reply with capture/listener at the root.
      const capture = value && value.capture ? value.capture : null
      if (!capture) throw new Error("Hex status did not include capture state")
      root.statusFailureCount = 0
      const captureState = String(capture.state || "unknown")
      root.activityState = captureState === "idle"
        ? (value.listener && value.listener.running ? "listening" : "idle")
        : captureState
      root.deviceName = ""
      root.errorText = capture.error ? String(capture.error)
        : value.model && value.model.error ? String(value.model.error) : ""
    } catch (e) {
      root.noteStatusFailure()
    }
  }

  function noteStatusFailure() {
    root.statusFailureCount++
    // Allow startup and self-update version handoffs a few polls to settle.
    if (root.statusFailureCount < 5) return
    root.activityState = "unavailable"
    root.errorText = "Hex status is unavailable"
  }

  function applyModels(text) {
    try {
      const value = JSON.parse(String(text || ""))
      const entries = Array.isArray(value) ? value : value.models
      if (!Array.isArray(entries)) throw new Error("No model list")
      root.models = entries.map(model => ({
        id: String(model.id || ""),
        name: String(model.name || model.id || "Model"),
        description: String(model.size || (model.languages || []).join(" · ") || "Local speech model"),
        installed: !!model.installed,
        selected: !!model.selected
      }))
      const selected = root.models.find(model => model.selected)
      if (selected) root.selectedModel = selected.id
      root.modelSelectionAvailable = !!value.can_select
      root.modelNote = String(value.note || "")
    } catch (e) {
      root.models = []
      root.modelSelectionAvailable = false
      root.modelNote = "Open Hex to manage transcription models"
    }
  }

  function applyHistory(text) {
    try {
      const value = JSON.parse(String(text || ""))
      if (value.version !== 1 || !Array.isArray(value.entries)) throw new Error("Unsupported Hex history format")
      root.selectedModel = String(value.selected_model || root.selectedModel)
      root.history = value.entries.filter(entry => typeof entry.final_text === "string")
        .map(entry => ({
          id: Number(entry.id), timestamp: Number(entry.timestamp_ms),
          kind: String(entry.kind || "dictation"), text: String(entry.final_text)
        }))
        .sort((a, b) => b.timestamp - a.timestamp)
    } catch (e) {
      root.history = []
      root.errorText = "Could not read Hex history"
    }
    root.loading = false
  }

  function run(args, action) {
    if (root.commandBusy) return
    root.commandBusy = true
    root.lastAction = action
    root.errorText = ""
    actionProc.exec(["hex"].concat(args))
  }

  function toggleDictation() { root.run(["dictation", "toggle"], "dictation") }
  function cancelDictation() { root.run(["dictation", "cancel"], "cancel") }
  function pasteLast() { root.run(["paste-last"], "paste") }
  function openApp() { root.run(["app"], "open") }

  function selectModel(id) {
    if (String(id) === root.selectedModel) return
    if (root.modelSelectionAvailable) root.run(["model", "use", String(id)], "model")
    else root.openApp()
  }

  function copyText(value, id) {
    root.pendingCopyId = Number(id ?? -1)
    root.copyFeedback = ""
    copyProc.exec(["sh", "-c", "printf '%s' \"$1\" | wl-copy", "kmdot", String(value || "")])
  }

  Component.onCompleted: if (DictationConfig.provider === "hex") root.refresh()

  Connections {
    target: DictationConfig
    function onProviderChanged() {
      if (DictationConfig.provider === "hex") root.refresh()
      else {
        root.activityState = "idle"
        root.errorText = ""
      }
    }
  }

  Timer {
    interval: 900
    repeat: true
    running: DictationConfig.provider === "hex"
    onTriggered: {
      root.requestStatus()
    }
  }

  Process {
    id: statusProc
    property string outputText: ""
    stdout: StdioCollector { onStreamFinished: statusProc.outputText = text }
    onExited: function(code) {
      if (code === 0) {
        root.applyStatus(statusProc.outputText)
        statusProc.outputText = ""
      } else {
        statusProc.outputText = ""
        root.noteStatusFailure()
      }
    }
  }
  Process {
    id: modelProc
    stdout: StdioCollector { onStreamFinished: root.applyModels(text) }
    onExited: function(code) {
      if (code !== 0) {
        root.models = []
        root.modelSelectionAvailable = false
        root.modelNote = "Open Hex to manage transcription models"
      }
    }
  }
  Process {
    id: historyProc
    stdout: StdioCollector { onStreamFinished: root.applyHistory(text) }
    onExited: function(code) {
      if (code !== 0) {
        root.history = []
        root.errorText = "Could not read Hex history"
        root.loading = false
      }
    }
  }
  Process {
    id: actionProc
    stderr: StdioCollector {}
    onExited: function(code) {
      root.commandBusy = false
      if (code !== 0) root.errorText = root.lastAction === "dictation" ? "Hex could not change dictation state"
        : root.lastAction === "cancel" ? "Hex could not cancel dictation"
        : root.lastAction === "paste" ? "Hex could not paste the last dictation"
        : root.lastAction === "model" ? "Hex could not switch models"
        : "Could not open Hex"
      root.refresh()
    }
  }
  Timer {
    id: copyFeedbackTimer
    interval: 1800
    onTriggered: {
      root.copiedHistoryId = -1
      root.copyFeedback = ""
    }
  }
  Process {
    id: copyProc
    onExited: function(code) {
      if (code === 0) {
        root.copiedHistoryId = root.pendingCopyId
        root.copyFeedback = "Copied to clipboard"
        copyFeedbackTimer.restart()
      } else {
        root.errorText = "Could not copy this dictation"
      }
    }
  }
}
