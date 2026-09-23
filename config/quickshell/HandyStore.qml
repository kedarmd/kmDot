pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import QtMultimedia

// Shared Handy store (spec #51; reads #52/#53, mutations #54, player #55).
// Owns the transcription models, the 5 most recent recordings, and the
// selected model, plus every mutation as the single writer: select model,
// retry a recording, delete a recording, and save an edited transcription.
// Busy/error status is owned once here; both views bind it read-only.
// refresh() coalesces concurrent callers into one in-flight fetch pair and
// caches models (rarely changing); post-mutation refetches touch history
// only via refreshHistory(). The handy-control.mjs verbs are unchanged.
// Audio playback is owned once here as well: a single player, a single stop
// guard, and single playing/progress/error state. Both views bind read-only
// and call togglePlay/stopPlayback; playback survives switching views and
// stops on explicit toggle, when all surfaces close (shell-level, outside
// the store), or when a mutating action starts.
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

  // ---- single audio player (issue #55) ----
  // One player, one stop guard, single playing/progress/error state. Views
  // bind these read-only and call togglePlay/stopPlayback; they own no
  // player of their own, so starting playback in one view while the other
  // plays switches cleanly on this same player — never overlapping audio.
  property int playingId: -1
  property real progress: 0
  property real positionMs: 0
  property real durationMs: 0
  property bool playbackStopping: false
  readonly property string recordingsDir: Quickshell.env("HOME") + "/.local/share/com.pais.handy/recordings"

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

  // ---- single audio player (issue #55) ----
  // Explicit toggle from either view. Same id stops; a different id
  // switches cleanly on the one player (stop-then-play, never overlapping).
  // Views pass the history row (id/fileName/audioAvailable/durationMs).
  function togglePlay(row) {
    if (!row) return
    const id = Number(row.id)
    if (root.playingId === id) {
      root.stopPlayback()
      return
    }
    if (!row.audioAvailable || !row.fileName) return
    root.playingId = id
    root.progress = 0
    root.positionMs = 0
    root.durationMs = Number(row.durationMs || 0)
    if (root.errorText !== "") root.errorText = ""
    root.playbackStopping = true
    player.stop()
    player.source = "file://" + root.recordingsDir + "/" + row.fileName
    root.playbackStopping = false
    player.play()
  }

  function stopPlayback() {
    root._resetPlaybackState()
    if (player.playbackState === MediaPlayer.PlayingState || String(player.source) !== "") {
      root.playbackStopping = true
      player.stop()
      player.source = ""
      root.playbackStopping = false
    }
  }

  // Shared reset for the single playback state (stop, natural end, error).
  // Never touches errorText — the error handler sets its message after this.
  function _resetPlaybackState() {
    root.playingId = -1
    root.progress = 0
    root.positionMs = 0
    root.durationMs = 0
  }

  function syncPlayback() {
    root.positionMs = player.position
    if (player.duration > 0) root.durationMs = player.duration
    root.progress = root.playingId >= 0 && root.durationMs > 0
      ? Math.min(1, root.positionMs / root.durationMs) : 0
  }

  // ---- single-writer mutations (issue #54) ----
  // Every Handy mutation runs through here; views call these and bind
  // busy/error read-only. Only one mutation at a time — a second call while
  // busy is ignored (views disable their controls while busy). Each stops
  // playback first so audio never leaks across a retry/delete/save/select.
  function selectModel(id) {
    if (root.busyAction !== "") return
    root.stopPlayback()
    root.busyAction = "select"
    root.busyId = -1
    if (root.errorText !== "") root.errorText = ""
    root._pendingMutation = "select"
    actionProc.exec(["node", root.script(), "select-model", String(id)])
  }

  function retry(id) {
    if (root.busyAction !== "") return
    root.stopPlayback()
    root.busyAction = "retry"
    root.busyId = Number(id)
    if (root.errorText !== "") root.errorText = ""
    root._pendingMutation = "retry"
    actionProc.exec(["node", root.script(), "retry", String(id), root.selectedModel])
  }

  function deleteEntry(id) {
    if (root.busyAction !== "") return
    root.stopPlayback()
    root.busyAction = "delete"
    root.busyId = Number(id)
    if (root.errorText !== "") root.errorText = ""
    root._pendingMutation = "delete"
    actionProc.exec(["node", root.script(), "delete", String(id)])
  }

  function saveText(id, text) {
    if (root.busyAction !== "") return
    root.stopPlayback()
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

  MediaPlayer {
    id: player
    audioOutput: AudioOutput {}
    onPositionChanged: root.syncPlayback()
    onDurationChanged: root.syncPlayback()
    // Natural end (or an external stop): reset state without raising an
    // error. Guarded so our own stopPlayback/togglePlay source swaps don't
    // double-reset mid-switch.
    onPlaybackStateChanged: {
      if (playbackState === MediaPlayer.StoppedState && !root.playbackStopping && root.playingId >= 0) {
        root._resetPlaybackState()
        if (String(player.source) !== "") {
          root.playbackStopping = true
          player.source = ""
          root.playbackStopping = false
        }
      }
    }
    // Failure surfaces a plain-language error and resets state.
    onErrorOccurred: {
      root.playbackStopping = true
      player.stop()
      player.source = ""
      root.playbackStopping = false
      root._resetPlaybackState()
      root.errorText = "Could not play recording"
    }
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
