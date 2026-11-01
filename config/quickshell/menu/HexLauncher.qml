import QtQuick
import Quickshell
import Quickshell.Io
import qs
import "../components"

// Hex follows the established Handy two-page layout. The backend is Hex's
// model/status CLI plus its documented, versioned retained-history file.
LauncherBase {
  id: root
  sockName: "kmdot-hex-launcher"
  castStyle: true
  title: "Hex"
  searchPlaceholder: "Search models…"
  headerTitle: root.mode === 0 ? "Hex · Models" : "Hex · History"
  cardHeight: 520
  countShown: false
  listToolbar: modeTabs
  toolbarBeforeSearch: true
  loadingText: "Loading Hex…"
  emptyText: root.mode === 0 ? "No models found" : "No dictations yet"
  searchEnabled: root.mode === 0
  headerText: root.mode === 1 ? "Hex History" : ""
  primaryActionText: root.mode === 0 ? "Select model" : "Copy"
  listErrorText: HexStore.errorText
  listStatusText: root.mode === 0 && HexStore.modelNote !== "" ? HexStore.modelNote : ""
  footerHint: DictationConfig.errorText !== "" ? DictationConfig.errorText
    : DictationConfig.switching ? "Switching dictation app…"
    : root.mode === 0 ? "↑↓ navigate · ↵ select · Tab switch" : "↑↓ navigate · ↵ copy · Tab switch"
  footerActionText: root.mode === 0 ? "Models" : "History"
  footerActionActive: true
  headerActionOptions: [{ id: "handy", title: "Handy" }, { id: "hex", title: "Hex" }]
  headerActionValue: DictationConfig.provider
  headerMenuLabel: DictationConfig.provider === "hex" ? "Hex" : "Handy"
  property int mode: 0
  property var models: HexStore.models
  property var history: HexStore.history
  property string selectedModel: HexStore.selectedModel

  function dateTitle(timestamp) {
    const date = new Date(Number(timestamp || 0))
    const now = new Date()
    const day = d => new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime()
    const days = Math.round((day(now) - day(date)) / 86400000)
    let hour = date.getHours()
    const suffix = hour >= 12 ? "PM" : "AM"
    hour = hour % 12 || 12
    const time = hour + ":" + String(date.getMinutes()).padStart(2, "0") + " " + suffix
    if (days === 0) return "Today, " + time
    if (days === 1) return "Yesterday, " + time
    return date.toLocaleDateString(undefined, { month: "short", day: "numeric" }) + ", " + time
  }

  function rebuildPool() {
    if (root.mode === 0) {
      const rows = root.models.map(model => ({
        kind: "model", modelId: model.id, label: model.name,
        subtitle: model.description, glyph: "\uf130", selected: model.selected
      }))
      rows.push({ kind: "manage", label: "Manage models in Hex", subtitle: HexStore.modelSelectionAvailable ? "Open Hex model settings" : "This Hex build manages model selection in its window", glyph: "\uf013" })
      root.pool = rows
      const selected = root.models.findIndex(model => model.selected || model.id === root.selectedModel)
      if (selected >= 0) root.selectedIndex = selected
    } else {
      root.pool = root.history.map(entry => ({
        kind: "history", entry: entry, id: entry.id, label: root.dateTitle(entry.timestamp),
        subtitle: "Dictation · press Enter to copy", body: String(entry.text || "").replace(/\s+/g, " ").trim(),
        searchText: String(entry.text || ""), glyph: "\uf130"
      }))
    }
  }

  function setMode(index) {
    if (root.mode === index) return
    root.animateResultsPage(index > root.mode ? 1 : -1)
    root.mode = index
    root.resetQuery()
    root.selectedIndex = 0
    root.rebuildPool()
  }

  function refreshItems() {
    root.mode = 0
    root.loading = true
    root.resetQuery()
    root.rebuildPool()
    HexStore.refresh()
  }

  function matchScore(item, query) {
    if (item.kind === "history") return root.fieldScore(item.searchText, query)
    return Math.max(root.fieldScore(item.label, query), root.fieldScore(item.subtitle, query))
  }

  function itemStatusGlyph(item) {
    if (item.kind === "history" && HexStore.copiedHistoryId === item.id) return "\uf00c"
    if (item.kind === "model" && (item.selected || item.modelId === root.selectedModel)) return "\uf00c"
    return ""
  }

  function itemSubtitleLive(item) {
    if (item.kind === "history" && HexStore.copiedHistoryId === item.id) return "Copied to clipboard"
    return root.itemSubtitle(item)
  }

  onModelsChanged: root.rebuildPool()
  onHistoryChanged: root.rebuildPool()
  onSelectedModelChanged: root.rebuildPool()
  function onOpenedChange() { if (root.opened) HexStore.refresh() }

  Connections {
    target: HexStore
    function onLoadingChanged() { root.loading = HexStore.loading }
    function onModelNoteChanged() { root.rebuildPool() }
  }

  Timer {
    interval: 3000
    repeat: true
    running: root.opened && root.mode === 1
    onTriggered: HexStore.refreshHistory()
  }

  onActivated: function(item) {
    if (!item) return
    if (item.kind === "history") HexStore.copyText(item.entry.text, item.id)
    else if (item.kind === "model") HexStore.selectModel(item.modelId)
    else if (item.kind === "manage") HexStore.openApp()
  }
  onFooterActionClicked: root.setMode(root.mode === 0 ? 1 : 0)
  onHeaderActionSelected: function(value) { DictationConfig.setProvider(value, true) }

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
            onClicked: root.setMode(index)
          }
        }
      }
    }
  }
}
