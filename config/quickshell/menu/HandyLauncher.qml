import QtQuick
import Quickshell
import Quickshell.Io
import "../components"
import qs

LauncherBase {
  id: root

  sockName: "kmdot-handy-launcher"
  castStyle: true
  title: "Handy"
  searchPlaceholder: "Search installed models…"
  headerTitle: root.mode === 0 ? "Handy" : "History"
  cardHeight: 520
  countShown: false
  listToolbar: modeTabs
  toolbarBeforeSearch: true
  loadingText: "Loading Handy\u2026"
  emptyText: root.mode === 0 ? "No installed models" : "No recordings yet"
  // History view drops the search bar so bare keys (Delete/Backspace) reach
  // the list; a title row takes its slot.
  searchEnabled: root.mode === 0
  headerGlyph: ""
  headerText: root.mode === 1 ? "Handy History" : ""
  primaryActionText: root.mode === 0 ? "Select model" : "Copy"
  listErrorText: HandyStore.errorText

  // Mode pill: shows the current mode; Tab or click flips it.
  footerActionGlyph: ""
  footerActionActive: true
  footerActionText: root.mode === 0 ? "Models" : "History"
  footerActionVisible: true
  headerActionOptions: [
    { id: "models", title: "Models" },
    { id: "history", title: "History" }
  ]
  headerActionValue: root.mode === 0 ? "models" : "history"
  // Store mutation/fetch errors surface here (the launcher has no error
  // line; the footer hint is its plain-language error surface).
  footerHint: root.mode === 0
    ? "↑↓ navigate · ↵ select · Tab switch"
    : (root.confirmId >= 0
      ? "Del again to confirm · Tab switch"
      : "↵ copy · Ctrl+P play · Ctrl+R retry · Del delete · Tab switch")
  // Secondary chords are History-only (retry/play); empty in Models mode so
  // the auto-appended hints disappear too.
  itemActions: root.mode === 1 ? [
    { key: Qt.Key_P, ctrl: true, hint: "Ctrl+P play" },
    { key: Qt.Key_R, ctrl: true, hint: "Ctrl+R retry" }
  ] : []
  // Bare Delete/Backspace delete the selected recording (History-only; the
  // searchless nav surface is what makes bare keys safe here).
  bareKeyActions: root.mode === 1 ? [
    { key: Qt.Key_Delete, hint: "Del delete" },
    { key: Qt.Key_Backspace, hint: "⌫ delete" }
  ] : []

  // 0 = Models, 1 = History. Opens on Models to mirror the tray popup's tabs.
  property int mode: 0
  // Reads, mutations, AND playback served by the HandyStore singleton
  // (issues #53/#54/#55, spec #51): the launcher binds its
  // models/history/selection/busy/error AND its playing/progress/position
  // state here instead of fetching, mutating, or playing itself. The store
  // owns the single player with its stop guard — the row status/subtitle/
  // progress seams below stay, bound read-only to that shared state.
  // Delete-arm (confirmId), clipboard, and key verbs stay view-local.
  property var models: HandyStore.models
  property var history: HandyStore.history
  property string selectedModel: HandyStore.selectedModel
  property int busyId: HandyStore.busyId
  property string busyAction: HandyStore.busyAction
  readonly property bool busy: HandyStore.busy
  readonly property int playingId: HandyStore.playingId
  readonly property real positionMs: HandyStore.positionMs
  readonly property real durationMs: HandyStore.durationMs
  readonly property real playbackProgress: HandyStore.progress
  // Two-click delete confirm: first Delete/Backspace arms the row's trash
  // glyph, the second (within 3s) deletes; anything else disarms via the
  // timer.
  property int confirmId: -1

  function fmtDur(ms) {
    const total = Math.max(0, Math.floor(Number(ms || 0) / 1000))
    return Math.floor(total / 60) + ":" + String(total % 60).padStart(2, "0")
  }
  // Bottom row is playback-only; the timestamp lives in the title.
  function playbackSubtitle(row) {
    if (!row.audioAvailable) return ""
    return "0:00 / " + (row.durationMs != null ? fmtDur(row.durationMs) : "--:--")
  }

  function historyTitle(row) {
    const raw = Number(row.timestamp || 0)
    if (!raw) return row.title || "Recording"
    const date = new Date(raw > 1000000000000 ? raw : raw * 1000)
    const now = new Date()
    const startToday = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime()
    const startDate = new Date(date.getFullYear(), date.getMonth(), date.getDate()).getTime()
    const daysAgo = Math.round((startToday - startDate) / 86400000)
    let hour = date.getHours()
    const ampm = hour >= 12 ? "PM" : "AM"
    hour = hour % 12 || 12
    const time = hour + ":" + String(date.getMinutes()).padStart(2, "0") + " " + ampm
    if (daysAgo === 0) return "Today, " + time
    if (daysAgo === 1) return "Yesterday, " + time
    const month = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][date.getMonth()]
    return month + " " + date.getDate() + ", " + time
  }

  function modelSubtitle(model) {
    const name = String(model.name || "")
    if (/whisper.*large/i.test(name)) return "Whisper · Multilingual"
    if (/parakeet/i.test(name)) return "Fast English transcription"
    if (/whisper.*small/i.test(name)) return "Whisper · Lightweight"
    if (/canary/i.test(name)) return "Multilingual transcription"
    return String(model.engine || "Installed model")
  }

  // ---- data (reads via HandyStore; one in-flight pair shared with popup) ----
  // Busy state is store-owned: opening the launcher never resets an
  // in-flight mutation, it only queues a coalesced refresh behind it.
  // Opening never stops playback either — audio survives switching views;
  // the shell stops the store player once BOTH Handy surfaces are closed.
  function refreshItems() {
    root.loading = true
    root.pool = []
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
      root.pool = root.models.map(m => ({ kind: "model", modelId: m.id, label: m.name, subtitle: root.modelSubtitle(m), glyph: "\uf130" }))
      const selected = root.models.findIndex(m => m.id === root.selectedModel)
      if (selected >= 0) root.selectedIndex = selected
    } else {
      root.pool = root.history.map(row => ({
        kind: "history",
        row,
        label: root.historyTitle(row),
        glyph: "\uf130",
        body: String(row.text || "").replace(/\s+/g, " ").trim(),
        subtitle: playbackSubtitle(row),
        searchText: (row.title || "") + " " + (row.text || "")
      }))
    }
  }

  function setMode(index) {
    if (root.mode === index) return
    root.animateResultsPage(index > root.mode ? 1 : -1)
    root.mode = index
    root.confirmId = -1
    root.resetQuery()
    root.selectedIndex = 0
    root.rebuildPool()
    root.recompute()
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
    if (item.kind === "model") return ""
    if (root.busyId === item.row.id && root.busyAction === "retry") return "\uf110"
    if (root.confirmId === item.row.id) return "\uf071"
    if (root.busyId === item.row.id && root.busyAction === "delete") return "\uf110"
    return ""
  }
  function itemMeta(item) {
    if (item.kind === "model") return item.modelId === root.selectedModel ? "Selected" : ""
    if (root.busyId === item.row.id) return ""
    if (root.confirmId === item.row.id) return "Delete"
    if (root.playingId === item.row.id) return "Pause"
    return item.row.audioAvailable ? "Play" : ""
  }
  function itemSubtitleLive(item) {
    if (item.kind !== "history") return itemSubtitle(item)
    if (root.confirmId === item.row.id) return "Press Del again to delete"
    if (root.busyId === item.row.id && root.busyAction === "retry") return "Retrying\u2026"
    if (root.playingId === item.row.id) {
      const total = root.durationMs > 0
        ? root.durationMs
        : (item.row.durationMs != null ? item.row.durationMs : 0)
      return "Playing · " + fmtDur(root.positionMs) + " / " + (total > 0 ? fmtDur(total) : "--:--")
    }
    return item.row.audioAvailable
      ? fmtDur(item.row.durationMs || 0) + " · Ready to copy"
      : ""
  }
  function itemProgress(item) {
    if (item.kind === "history" && root.playingId === item.row.id)
      return root.playbackProgress
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
    HandyStore.deleteEntry(item.row.id)
  }

  onActivated: function(item) {
    if (item.kind === "model") {
      if (root.busy || item.modelId === root.selectedModel) return
      HandyStore.selectModel(item.modelId)
    } else {
      copyProc.exec(["sh", "-c", "printf '%s' \"$1\" | wl-copy", "kmdot", item.row.text || ""])
    }
  }

  onFooterActionClicked: {
    root.setMode(root.mode === 0 ? 1 : 0)
  }

  onHeaderActionSelected: function(value) {
    root.setMode(value === "history" ? 1 : 0)
  }

  Timer {
    id: confirmTimer
    interval: 3000
    onTriggered: root.confirmId = -1
  }

  function startRetry(item) {
    if (!item.row.audioAvailable || root.busy) return
    HandyStore.retry(item.row.id)
  }

  // ---- playback (store-owned, issue #55) ----
  // Toggle delegates to the one shared player: starting a recording here
  // while the popup plays switches cleanly, never overlapping. No stop on
  // close here — the shell stops the player once BOTH surfaces are closed
  // so audio survives switching views.
  function togglePlay(item) {
    HandyStore.togglePlay(item.row)
  }

  function onOpenedChange() {
    if (!root.opened) root.confirmId = -1
  }

  // Clears loading when the shared pair settles even if the payloads are
  // identical (no models/history change signals to ride on).
  Connections {
    target: HandyStore
    function onRefreshingChanged() { if (!HandyStore.refreshing) root.syncFromStore() }
  }

  Process { id: copyProc }

  Component {
    id: modeTabs
    Row {
      width: parent.width
      spacing: 16

      Repeater {
        model: ["Models", "History"]
        delegate: Rectangle {
          required property string modelData
          required property int index
          width: (parent.width - parent.spacing) / 2
          height: 40
          radius: 20
          color: root.mode === index ? Tokens.pill : Colors.surface_alt

          Text {
            anchors.centerIn: parent
            text: modelData
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
            font.weight: root.mode === index ? Font.DemiBold : Font.Medium
            color: root.mode === index ? Tokens.on_pill : Colors.text_alt
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.setMode(index)
            }
          }
        }
      }
    }
  }
}
