import QtQuick
import Quickshell
import Quickshell.Io
import QtMultimedia
import "../components"
import qs

LauncherBase {
  id: root

  sockName: "kmdot-handy-launcher"
  title: "Handy"
  countShown: false
  loadingText: "Loading Handy\u2026"
  emptyText: root.mode === 0 ? "No installed models" : "No recordings yet"
  // History view drops the search bar so bare keys (Delete/Backspace) reach
  // the list; a title row takes its slot.
  searchEnabled: root.mode === 0
  headerGlyph: "\uf130"
  headerText: "Handy History"

  // Mode pill: shows the current mode; Tab or click flips it.
  footerActionGlyph: "\uf0ec"
  footerActionActive: true
  footerActionText: root.mode === 0 ? "Models" : "History"
  footerHint: root.mode === 0
    ? "\u2191\u2193 navigate \u00b7 \u23ce select \u00b7 esc close"
    : (root.confirmId >= 0
      ? "Del again to confirm"
      : "\u2191\u2193 navigate \u00b7 \u23ce copy \u00b7 esc close")
  // Secondary chords are History-only (retry/play); empty in Models mode so
  // the auto-appended hints disappear too.
  itemActions: root.mode === 1 ? [
    { key: Qt.Key_R, ctrl: true, hint: "^R retry" },
    { key: Qt.Key_P, ctrl: true, hint: "^P play" }
  ] : []
  // Bare Delete/Backspace delete the selected recording (History-only; the
  // searchless nav surface is what makes bare keys safe here).
  bareKeyActions: root.mode === 1 ? [
    { key: Qt.Key_Delete, hint: "Del delete" },
    { key: Qt.Key_Backspace, hint: "\u232b delete" }
  ] : []

  // 0 = Models, 1 = History. Opens on Models to mirror the tray popup's tabs.
  property int mode: 0
  // Read path served by the HandyStore singleton (issue #53, spec #51): the
  // launcher binds its models/history/selection here instead of fetching them
  // itself. Mutations, playback, and key verbs stay view-local.
  property var models: HandyStore.models
  property var history: HandyStore.history
  property string selectedModel: HandyStore.selectedModel
  property int busyId: -1
  property string busyAction: ""
  readonly property bool busy: busyAction !== ""
  property string pendingCommand: ""
  property int playingId: -1
  property bool playbackStopping: false
  // Two-click delete confirm: first click arms the row's trash glyph, the
  // second (within 3s) deletes; anything else disarms via the timer.
  property int confirmId: -1
  readonly property string recordingsDir: Quickshell.env("HOME") + "/.local/share/com.pais.handy/recordings"

  function script() { return Quickshell.env("HOME") + "/.config/kmdot/quickshell/scripts/handy-control.mjs" }

  function fmtDur(ms) {
    const total = Math.max(0, Math.floor(Number(ms || 0) / 1000))
    return Math.floor(total / 60) + ":" + String(total % 60).padStart(2, "0")
  }
  // Bottom row is playback-only; the timestamp lives in the title.
  function playbackSubtitle(row) {
    if (!row.audioAvailable) return ""
    return "0:00 / " + (row.durationMs != null ? fmtDur(row.durationMs) : "--:--")
  }

  // ---- data (reads via HandyStore; one in-flight pair shared with popup) ----
  function refreshItems() {
    root.loading = true
    root.pool = []
    root.stopPlayback()
    root.busyAction = ""
    root.busyId = -1
    root.pendingCommand = ""
    root.confirmId = -1
    root.mode = 0
    // Show cached store data instantly while the refetch runs; the store
    // change handlers rebuild again when fresh data lands.
    root.rebuildPool()
    HandyStore.refresh()
  }

  // Rebuilds the pool from the store; clears loading once the shared fetch
  // pair has settled. Empty history yields an empty pool (plain empty state,
  // never an error — the launcher shows no fetch errors).
  function syncFromStore() {
    root.rebuildPool()
    if (!HandyStore.refreshing) root.loading = false
  }

  onModelsChanged: root.syncFromStore()
  onHistoryChanged: root.syncFromStore()
  onSelectedModelChanged: root.rebuildPool()

  // ---- pool ----
  function rebuildPool() {
    if (root.mode === 0) {
      root.pool = root.models.map(m => ({ kind: "model", modelId: m.id, label: m.name, subtitle: m.engine }))
    } else {
      root.pool = root.history.map(row => ({
        kind: "history",
        row,
        label: row.title || "Recording",
        body: String(row.text || "").replace(/\s+/g, " ").trim(),
        subtitle: playbackSubtitle(row),
        searchText: (row.title || "") + " " + (row.text || "")
      }))
    }
  }

  // History searches the full transcription text; Models keep label/engine.
  function matchScore(item, q) {
    let best = -1
    const fields = item.kind === "history" ? [item.label, item.searchText] : [item.label, item.subtitle]
    for (const f of fields) {
      if (f === undefined || f === null) continue
      const s = root.fieldScore(f, q)
      if (s >= 0 && s > best) best = s
    }
    return best
  }

  // ---- row-local seams ----
  function itemStatusGlyph(item) {
    if (item.kind === "model") return item.modelId === root.selectedModel ? "\uf00c" : ""
    if (root.busyId === item.row.id && root.busyAction === "retry") return "\uf110"
    if (root.confirmId === item.row.id) return "\uf071"
    if (root.busyId === item.row.id && root.busyAction === "delete") return "\uf110"
    if (root.playingId === item.row.id) return "\uf04c"
    return item.row.audioAvailable ? "\uf04b" : ""
  }
  function itemSubtitleLive(item) {
    if (item.kind !== "history") return itemSubtitle(item)
    if (root.confirmId === item.row.id) return "Press Del again to delete"
    if (root.busyId === item.row.id && root.busyAction === "retry") return "Retrying\u2026"
    if (root.playingId === item.row.id) {
      const total = player.duration > 0 ? player.duration
        : (item.row.durationMs != null ? item.row.durationMs : 0)
      return fmtDur(player.position) + " / " + (total > 0 ? fmtDur(total) : "--:--")
    }
    return playbackSubtitle(item.row)
  }
  function itemProgress(item) {
    if (item.kind === "history" && root.playingId === item.row.id && player.duration > 0)
      return Math.min(1, player.position / player.duration)
    return 0
  }

  // ---- actions ----
  onItemAction: function(action, item) {
    if (item.kind !== "history" || root.busy) return
    if (action.key === Qt.Key_R) startRetry(item)
    else if (action.key === Qt.Key_P) togglePlay(item)
    else if (action.key === Qt.Key_Delete || action.key === Qt.Key_Backspace) handleDeleteKey(item)
  }

  // Two-click confirm on the keyboard: first Delete/Backspace arms the row,
  // the second (within 3s) deletes; anything else disarms via the timer.
  function handleDeleteKey(item) {
    if (root.confirmId !== item.row.id) {
      root.confirmId = item.row.id
      confirmTimer.restart()
      return
    }
    confirmTimer.stop()
    startDelete(item)
  }

  function startDelete(item) {
    root.confirmId = -1
    if (root.playingId === item.row.id) root.stopPlayback()
    root.busyId = item.row.id
    root.busyAction = "delete"
    root.pendingCommand = "delete"
    actionProc.exec(["node", root.script(), "delete", String(item.row.id)])
  }

  onActivated: function(item) {
    if (item.kind === "model") {
      if (root.busy || item.modelId === root.selectedModel) return
      root.busyAction = "select"
      root.pendingCommand = "select-model"
      actionProc.exec(["node", root.script(), "select-model", item.modelId])
    } else {
      copyProc.exec(["sh", "-c", "printf '%s' \"$1\" | wl-copy", "kmdot", item.row.text || ""])
    }
  }

  onFooterActionClicked: {
    root.mode = root.mode === 0 ? 1 : 0
    root.confirmId = -1
    root.resetQuery()
    root.selectedIndex = 0
    root.rebuildPool()
    root.recompute()
  }

  Timer {
    id: confirmTimer
    interval: 3000
    onTriggered: root.confirmId = -1
  }

  function startRetry(item) {
    if (!item.row.audioAvailable) return
    root.busyId = item.row.id
    root.busyAction = "retry"
    root.pendingCommand = "retry"
    actionProc.exec(["node", root.script(), "retry", String(item.row.id), root.selectedModel])
  }

  // ---- playback (mirrors HandyPopup's wiring) ----
  function stopPlayback() {
    playingId = -1
    if (player.playbackState === MediaPlayer.PlayingState || player.source.toString() !== "") {
      playbackStopping = true
      player.stop()
      player.source = ""
      playbackStopping = false
    }
  }
  function togglePlay(item) {
    if (root.playingId === item.row.id) { stopPlayback(); return }
    if (!item.row.audioAvailable) return
    root.playingId = item.row.id
    playbackStopping = true
    player.stop()
    player.source = "file://" + recordingsDir + "/" + item.row.fileName
    playbackStopping = false
    player.play()
  }

  function onOpenedChange() {
    if (!root.opened) root.stopPlayback()
  }

  // Clears loading when the shared pair settles even if the payloads are
  // identical (no models/history change signals to ride on).
  Connections {
    target: HandyStore
    function onRefreshingChanged() { if (!HandyStore.refreshing) root.syncFromStore() }
  }

  Process {
    id: actionProc
    stdout: StdioCollector {
      onStreamFinished: {
        const wasRetry = root.pendingCommand === "retry"
        const wasDelete = root.pendingCommand === "delete"
        const wasSelect = root.pendingCommand === "select-model"
        root.pendingCommand = ""
        root.busyAction = ""
        root.busyId = -1
        try {
          const result = JSON.parse(String(this.text))
          if (!result.ok) {
            console.warn("handy-launcher:", result.error || "operation failed")
          } else if (wasSelect && result.selected) {
            // Reads live in HandyStore; select-model updates it here, and
            // retry/delete refetch history through it (models cached, so
            // history-only) instead of a launcher-local fetch.
            HandyStore.selectedModel = result.selected
          }
        } catch (e) { console.warn("handy-launcher: unparseable action response") }
        if (wasRetry || wasDelete) HandyStore.refresh()
      }
    }
  }
  Process { id: copyProc }
  MediaPlayer {
    id: player
    audioOutput: AudioOutput {}
    onPlaybackStateChanged: if (playbackState === MediaPlayer.StoppedState && !root.playbackStopping) root.stopPlayback()
    onErrorOccurred: root.stopPlayback()
  }
}
