pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

// Shared Handy store (spec #51; reads #52/#53, mutations #54).
// Owns the transcription models, the 5 most recent recordings, and the
// selected model, plus every mutation as the single writer: select model,
// retry a recording, delete a recording, and save an edited transcription.
// Busy/error status is owned once here; both views bind it read-only.
// refresh() coalesces concurrent callers into one in-flight fetch pair and
// caches models (rarely changing); post-mutation refetches touch history
// only via refreshHistory(). The handy-control.mjs verbs are unchanged.
Singleton {
  id: root

  property var models: []
  property var history: []
  property string selectedModel: ""
  property string errorText: ""

  // Single-writer mutation status (issue #54): which action is in flight and
  // on which recording (busyId -1 for model select, which is not per-row).
  // Views bind these read-only and never assign them.
  property int busyId: -1
  property string busyAction: ""
  readonly property bool busy: root.busyAction !== ""
  // Pending mutation command ("select"/"retry"/"delete"/"save") for the
  // single actionProc below; only one mutation runs at a time.
  property string _pendingMutation: ""

  readonly property bool refreshing: root._historyBusy || root._modelsBusy

  property bool _historyBusy: false
  property bool _modelsBusy: false
  property bool _modelsLoaded: false
  // Set when refresh() is called while a pair is in flight; drained as one
  // follow-up refresh once the pair settles, so no caller is dropped.
  property bool _refreshQueued: false

  function script() { return Quickshell.env("HOME") + "/.config/kmdot/quickshell/scripts/handy-control.mjs" }

  // Coalesced refresh: one in-flight pair shared by all callers. A refresh
  // while either fetch — or a mutation — is running queues a single follow-up
  // instead of spawning doubled runtimes. History refetches every time;
  // models fetch once per shell lifetime (cached), retrying on failure.
  function refresh() {
    if (root.busyAction !== "" || root._historyBusy || root._modelsBusy) {
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

  // Drains one queued refresh once the whole pair has settled and no
  // mutation is in flight (mutation completion drains via _drainQueue).
  function _settle() {
    if (root._historyBusy || root._modelsBusy || root.busyAction !== "") return
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

  // History-only refetch after a mutation: models are cached, so this never
  // touches them. Queues behind an in-flight history fetch instead of
  // doubling runtimes; runs independently of a models fetch.
  function refreshHistory() {
    if (root._historyBusy) {
      root._refreshQueued = true
      return
    }
    root._historyBusy = true
    historyProc.exec(["node", root.script(), "history"])
  }

  // ---- single-writer mutations (issue #54) ----
  // Every Handy mutation runs through here; views call these and bind
  // busy/error read-only. Only one mutation at a time — a second call while
  // busy is ignored (views disable their controls while busy).
  function selectModel(id) {
    if (root.busyAction !== "") return
    root.busyAction = "select"
    root.busyId = -1
    if (root.errorText !== "") root.errorText = ""
    root._pendingMutation = "select"
    actionProc.exec(["node", root.script(), "select-model", String(id)])
  }

  function retry(id) {
    if (root.busyAction !== "") return
    root.busyAction = "retry"
    root.busyId = Number(id)
    if (root.errorText !== "") root.errorText = ""
    root._pendingMutation = "retry"
    actionProc.exec(["node", root.script(), "retry", String(id), root.selectedModel])
  }

  function deleteEntry(id) {
    if (root.busyAction !== "") return
    root.busyAction = "delete"
    root.busyId = Number(id)
    if (root.errorText !== "") root.errorText = ""
    root._pendingMutation = "delete"
    actionProc.exec(["node", root.script(), "delete", String(id)])
  }

  function saveText(id, text) {
    if (root.busyAction !== "") return
    root.busyAction = "save"
    root.busyId = Number(id)
    if (root.errorText !== "") root.errorText = ""
    root._pendingMutation = "save"
    actionProc.exec(["node", root.script(), "save", String(id), String(text)])
  }

  // Drains a refresh queued during a mutation once nothing is in flight.
  function _drainQueue() {
    if (root._refreshQueued && !root._historyBusy && !root._modelsBusy && root.busyAction === "") {
      root._refreshQueued = false
      refresh()
    }
  }

  function _applyAction(text) {
    const cmd = root._pendingMutation
    root._pendingMutation = ""
    root.busyAction = ""
    root.busyId = -1
    let ok = false
    try {
      const result = JSON.parse(String(text))
      if (!result.ok) {
        root.errorText = result.error || "Handy operation failed"
      } else {
        ok = true
        if (result.selected) root.selectedModel = result.selected
      }
    } catch (e) {
      root.errorText = "Could not parse Handy response"
    }
    // Select only moves the selection — nothing changed in history. Every
    // other mutation refetches history only (models stay cached). A refresh
    // queued mid-mutation still runs, but it must not swallow a failure:
    // refresh() clears the error, so re-assert it afterwards.
    if (ok && cmd !== "select") root.refreshHistory()
    const keptError = root.errorText
    root._drainQueue()
    if (!ok && keptError !== "" && root.errorText === "") root.errorText = keptError
  }

  Process {
    id: modelsProc
    stdout: StdioCollector { onStreamFinished: root._applyModels(String(this.text)) }
  }

  Process {
    id: historyProc
    stdout: StdioCollector { onStreamFinished: root._applyHistory(String(this.text)) }
  }

  Process {
    id: actionProc
    stdout: StdioCollector { onStreamFinished: root._applyAction(String(this.text)) }
  }
}
