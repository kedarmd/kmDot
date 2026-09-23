pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

// Shared Handy read store (issues #52/#53, spec #51).
// Owns the transcription models, the 5 most recent recordings, and the
// selected model. Serves reads for the tray popup and the launcher.
// Mutations, playback, and key verbs stay view-local for now — this store
// is reads only: refresh() coalesces concurrent callers into one in-flight
// fetch pair and caches models (rarely changing) so refetches touch history
// only. The handy-control.mjs verbs are unchanged.
Singleton {
  id: root

  property var models: []
  property var history: []
  property string selectedModel: ""
  property string errorText: ""

  readonly property bool refreshing: root._historyBusy || root._modelsBusy

  property bool _historyBusy: false
  property bool _modelsBusy: false
  property bool _modelsLoaded: false
  // Set when refresh() is called while a pair is in flight; drained as one
  // follow-up refresh once the pair settles, so no caller is dropped.
  property bool _refreshQueued: false

  function script() { return Quickshell.env("HOME") + "/.config/kmdot/quickshell/scripts/handy-control.mjs" }

  // Coalesced refresh: one in-flight pair shared by all callers. A refresh
  // while either fetch is running queues a single follow-up instead of
  // spawning doubled runtimes. History refetches every time; models fetch
  // once per shell lifetime (cached), retrying on failure.
  function refresh() {
    if (root._historyBusy || root._modelsBusy) {
      root._refreshQueued = true
      return
    }
    if (!root._modelsLoaded) {
      root._modelsBusy = true
      modelsProc.exec(["node", root.script(), "models"])
    }
    root._historyBusy = true
    historyProc.exec(["node", root.script(), "history"])
    if (root.errorText !== "") root.errorText = ""
  }

  // Drains one queued refresh once the whole pair has settled.
  function _settle() {
    if (root._historyBusy || root._modelsBusy) return
    if (root._refreshQueued) {
      root._refreshQueued = false
      refresh()
    }
  }

  function _applyModels(text) {
    try {
      const result = JSON.parse(String(text))
      if (result.ok) {
        root.models = result.models || []
        if (result.selected) root.selectedModel = result.selected
        root._modelsLoaded = true
      } else {
        root.errorText = result.error || "Could not load Handy models"
      }
    } catch (e) {
      root.errorText = "Could not parse Handy response"
    }
    root._modelsBusy = false
    root._settle()
  }

  function _applyHistory(text) {
    try {
      const result = JSON.parse(String(text))
      if (result.ok) {
        root.history = result.history || []
      } else {
        root.errorText = result.error || "Could not load Handy history"
        root.history = []
      }
    } catch (e) {
      root.errorText = "Could not parse Handy response"
      root.history = []
    }
    root._historyBusy = false
    root._settle()
  }

  Process {
    id: modelsProc
    stdout: StdioCollector { onStreamFinished: root._applyModels(String(this.text)) }
  }

  Process {
    id: historyProc
    stdout: StdioCollector { onStreamFinished: root._applyHistory(String(this.text)) }
  }
}
