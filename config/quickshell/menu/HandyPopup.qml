import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import qs
import "../components"

PopupBase {
  id: root
  sockName: "kmdot-handy"
  cardWidth: 424
  cardMinHeight: root.tab === 0 ? 536 : 624
  cardMaxHeight: root.tab === 0 ? Math.max(536, root.modelListHeight + 272) : 624

  property int tab: 0
  onTabChanged: {
    if (root.tab === 1) {
      root.selectedHistoryId = root.history.length > 0 ? root.history[0].id : -1
      Qt.callLater(function() { historyList.positionViewAtBeginning() })
    }
  }

  // Match the Coding Agent panel's page choreography: place the incoming
  // page just offscreen before changing tabs, then animate both pages across.
  function switchTab(index) {
    if (root.tab === index) return
    const direction = index > root.tab ? 1 : -1
    if (index === 1) {
      historyPage.x = historyPage.width * direction
      root.tab = index
      modelList.x = -modelList.width * direction
      historyPage.x = 0
    } else {
      modelList.x = modelList.width * direction
      root.tab = index
      historyPage.x = -historyPage.width * direction
      modelList.x = 0
    }
  }
  // Reads, mutations, AND playback served by the HandyStore singleton
  // (issues #52/#54/#55): the popup binds its models/history/selection/
  // busy/error AND its playing/progress/position state here instead of
  // fetching, mutating, or playing itself. The store owns the single player
  // with its stop guard — this view keeps only its progress bar, time
  // readout, and error line, all bound read-only. Delete-arm (confirmId)
  // and clipboard stay view-local.
  property var models: HandyStore.models
  property var history: HandyStore.history
  property string selectedModel: HandyStore.selectedModel
  property int busyId: HandyStore.busyId
  property string busyAction: HandyStore.busyAction
  readonly property bool busy: HandyStore.busy
  readonly property int playingId: HandyStore.playingId
  readonly property real progress: HandyStore.progress
  readonly property real positionMs: HandyStore.positionMs
  readonly property real durationMs: HandyStore.durationMs
  readonly property string effectiveError: HandyStore.errorText
  property int selectedHistoryId: history.length > 0 ? history[0].id : -1
  readonly property real modelListHeight: Math.max(72, Math.min(440, models.length * 72 + Math.max(0, models.length - 1) * 8))
  readonly property real historyListHeight: history.length === 0 ? 72 : 408
  // Two-click delete confirm: first click arms the row's pill ("Sure?"), the
  // second (within 3s) deletes.
  property int confirmId: -1
  property var pendingDeleteRow: null

  function requestDelete(row) {
    if (root.busy || !root.scope || !root.scope.confirmPopup) return
    root.pendingDeleteRow = row
    root.scope.confirmPopup.ask("Delete recording?", root.historyTitle(row.timestamp), {
      showKeyboardHints: false,
      titleGlyph: "\uf1f8", titleGlyphColor: Colors.text,
      supportingText: "This deletes the recording and its transcription. This action cannot be undone.",
      confirmText: "Delete", cancelText: "Keep recording",
      confirmFill: Colors.error, confirmTextColor: Colors.surface
    })
  }

  Connections {
    target: root.scope ? root.scope.confirmPopup : null
    function onConfirmed() {
      if (!root.pendingDeleteRow) return
      const row = root.pendingDeleteRow
      root.pendingDeleteRow = null
      root.remove(row)
      root.open()
    }
    function onCancelled() {
      if (!root.pendingDeleteRow) return
      root.pendingDeleteRow = null
      // A different overlay may be replacing the confirmation. Reopen only
      // for a direct Cancel/Escape/backdrop dismissal, not during coordination.
      if (!root.scope.openingSurface) root.open()
    }
  }

  function refreshItems() { refresh() }
  // Closing one surface never stops playback here — audio survives switching
  // views. The shell stops the store player once BOTH Handy surfaces are
  // closed (playback lifecycle lives outside the store, per spec #51).
  function openedChange() {
    if (!root.opened) {
      confirmId = -1
    }
  }
  function refresh() {
    confirmId = -1
    HandyStore.refresh()
  }
  // Mutations run through the store (single writer, single player): the
  // store stops playback itself when the action starts, so this view never
  // pre-stops. Delete-arm stays per-surface: the row disarms below once the
  // entry disappears from the shared history.
  function remove(row) {
    HandyStore.deleteEntry(row.id)
  }
  function fmtTime(epoch) {
    return new Date(epoch * 1000).toLocaleString(undefined, { month: "short", day: "numeric", hour: "numeric", minute: "2-digit" })
  }
  function historyTitle(epoch) {
    const date = new Date(Number(epoch || 0) * 1000)
    const now = new Date()
    const day = new Date(date.getFullYear(), date.getMonth(), date.getDate()).getTime()
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime()
    const days = Math.round((today - day) / 86400000)
    let hour = date.getHours()
    const suffix = hour >= 12 ? "PM" : "AM"
    hour = hour % 12 || 12
    const time = hour + ":" + String(date.getMinutes()).padStart(2, "0") + " " + suffix
    if (days === 0) return "Today, " + time
    if (days === 1) return "Yesterday, " + time
    return date.toLocaleDateString(undefined, { month: "short", day: "numeric" }) + ", " + time
  }
  function fmtDur(ms) {
    const total = Math.max(0, Math.floor(Number(ms || 0) / 1000))
    return Math.floor(total / 60) + ":" + String(total % 60).padStart(2, "0")
  }
  function modelDescription(model) {
    const name = String(model.name || "")
    if (/whisper.*large/i.test(name)) return "Whisper · Multilingual"
    if (/parakeet/i.test(name)) return "Fast English transcription"
    if (/whisper.*small/i.test(name)) return "Whisper · Lightweight"
    if (/canary/i.test(name)) return "Multilingual transcription"
    return "Installed transcription model"
  }
  // Playback is store-owned (issue #55): toggle delegates, never overlaps —
  // starting a recording here switches the one shared player even if the
  // launcher is playing, and vice versa.
  function togglePlay(row) {
    HandyStore.togglePlay(row)
  }
  function selectModel(id) {
    if (root.busy) return
    HandyStore.selectModel(id)
  }
  function retry(row) {
    if (root.busy || !row.audioAvailable) return
    HandyStore.retry(row.id)
  }
  function save(row, text) {
    if (root.busy) return
    HandyStore.saveText(row.id, text)
  }
  function copy(text) { copyProc.exec(["sh", "-c", "printf '%s' \"$1\" | wl-copy", "kmdot", text]) }
  Timer {
    id: confirmTimer
    interval: 3000
    onTriggered: root.confirmId = -1
  }
  // Delete-arm is per-surface (issue #54): the row disarms once the entry
  // disappears from the shared history; a failed delete leaves it armed
  // until the timer fires, so a second press retries.
  Connections {
    target: HandyStore
    function onHistoryChanged() {
      if (root.selectedHistoryId < 0 || !HandyStore.history.find(row => row.id === root.selectedHistoryId))
        root.selectedHistoryId = HandyStore.history.length > 0 ? HandyStore.history[0].id : -1
      if (root.confirmId < 0) return
      for (let i = 0; i < HandyStore.history.length; i++) {
        if (HandyStore.history[i].id === root.confirmId) return
      }
      root.confirmId = -1
    }
  }
  Process { id: copyProc }

        Item {
          width: parent.width; height: 28
          R1Icon { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: 2; width: 24; height: 24; glyph: "\uf130"; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 20; color: Colors.text; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
          Text { anchors.left: parent.left; anchors.leftMargin: 40; anchors.verticalCenter: parent.verticalCenter; text: "Handy"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 24; font.weight: Font.DemiBold; color: Colors.text }
          Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: root.busy ? "Working" : ""; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: Tokens.mutedText }
        }

        Item { width: parent.width; height: 4 }
        Row {
          width: parent.width; spacing: 8
          PillButton { width: (parent.width - 8) / 2; text: "Models"; textSize: 14; emphasized: true; filled: true; inactiveFillColor: Colors.surface_alt; active: root.tab === 0; onClicked: root.switchTab(0) }
          PillButton { width: (parent.width - 8) / 2; text: "History"; textSize: 14; emphasized: true; filled: true; inactiveFillColor: Colors.surface_alt; active: root.tab === 1; onClicked: root.switchTab(1) }
        }
        Text { visible: root.effectiveError !== ""; width: parent.width; height: visible ? implicitHeight : 0; text: root.effectiveError; color: Tokens.errorText; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; wrapMode: Text.WordWrap }

        Item {
          id: handyPages
          property bool pagesReady: false
          width: parent.width
          height: Math.max(root.modelListHeight, root.historyListHeight + 16)
          clip: true

          ListView {
          id: modelList
          visible: true
          width: parent.width
          height: root.modelListHeight
          spacing: 8
          clip: true
          interactive: contentHeight > height
          Behavior on x {
            enabled: handyPages.pagesReady
            NumberAnimation { duration: Tokens.motionEmphasized; easing.type: Tokens.motionEasing }
          }
          model: root.models
          delegate: Rectangle {
            required property var modelData
            width: modelList.width; height: 72; radius: 16
            color: modelData.id === root.selectedModel ? Tokens.primaryContainer : Tokens.surfaceContainerHighest
            R1Icon { anchors.left: parent.left; anchors.leftMargin: 16; anchors.verticalCenter: parent.verticalCenter; width: 24; height: 24; glyph: "\uf130"; color: modelData.id === root.selectedModel ? Tokens.on_primary_container : Colors.text_alt; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 20; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            Column { anchors.left: parent.left; anchors.leftMargin: 56; anchors.right: trailing.left; anchors.verticalCenter: parent.verticalCenter; spacing: 4
              Text { width: parent.width; text: modelData.name; color: modelData.id === root.selectedModel ? Tokens.on_primary_container : Colors.text; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; font.weight: modelData.id === root.selectedModel ? Font.DemiBold : Font.Normal; elide: Text.ElideRight }
              Text { width: parent.width; text: root.modelDescription(modelData); color: modelData.id === root.selectedModel ? Tokens.on_primary_container : Colors.text_alt; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; elide: Text.ElideRight }
            }
            R1Icon { id: trailing; anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; glyph: modelData.id === root.selectedModel ? "\uf00c" : "\uf054"; color: modelData.id === root.selectedModel ? Tokens.on_primary_container : Colors.text_alt; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 14 }
            MouseArea { anchors.fill: parent; enabled: !root.busy; onClicked: root.selectModel(modelData.id) }
          }
        }

          Item {
          id: historyPage
          visible: true
          width: parent.width
          height: root.historyListHeight + 16
          clip: true
          Behavior on x {
            enabled: handyPages.pagesReady
            NumberAnimation { duration: Tokens.motionEmphasized; easing.type: Tokens.motionEasing }
          }
          ListView {
          id: historyList
          onVisibleChanged: {
            if (!visible) return
            root.selectedHistoryId = root.history.length > 0 ? root.history[0].id : -1
            Qt.callLater(function() { historyList.positionViewAtBeginning() })
          }
          anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 16 }
          width: parent.width
          height: root.historyListHeight
          spacing: 16
          clip: true
          interactive: contentHeight > height
          model: root.history
          delegate: Rectangle {
            id: historyRow
            required property var modelData
            readonly property bool isPlaying: root.playingId === modelData.id
            readonly property bool selected: root.selectedHistoryId === modelData.id
            width: historyList.width; height: selected ? 320 : 72; radius: selected ? 24 : 16
            color: Tokens.surfaceContainer
            Text {
              visible: historyRow.selected
              anchors.left: parent.left; anchors.leftMargin: 16; anchors.top: parent.top; anchors.topMargin: 20
              text: root.historyTitle(modelData.timestamp); color: Colors.text_alt; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.weight: Font.DemiBold
            }
            TextEdit {
            selectionColor: Colors.text_selection
            selectedTextColor: Colors.on_text_selection
              cursorDelegate: Rectangle { width: 2; height: editor.cursorRectangle.height; color: Colors.cursor }
              id: editor
              visible: historyRow.selected
              anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
              width: parent.width - 32; height: 112; clip: true; text: modelData.text; color: Colors.text; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 20; wrapMode: TextEdit.Wrap; selectByMouse: true; persistentSelection: true
              anchors.leftMargin: 16; anchors.rightMargin: 16; anchors.topMargin: 56
              readOnly: root.busy && root.busyId !== modelData.id
            }
            Item {
              visible: historyRow.selected && modelData.audioAvailable
              anchors { left: parent.left; right: parent.right; margins: 16; top: editor.bottom; topMargin: 20 }
              height: 58
              Rectangle {
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: 4; color: Colors.slider_track
                Rectangle {
                  anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                  width: parent.width * (historyRow.isPlaying ? root.progress : 0)
                  color: Colors.primary
                  Behavior on width { NumberAnimation { duration: Tokens.meterMotion; easing.type: Easing.Linear } }
                }
              }
              Item {
                id: playButton
                anchors { left: parent.left; verticalCenter: retryButton.verticalCenter }
                width: 24; height: 24
                Shape {
                  anchors.fill: parent
                  visible: historyRow.isPlaying
                  ShapePath {
                    strokeColor: Colors.text; strokeWidth: 1.8; fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    startX: 8; startY: 4
                    PathLine { x: 8; y: 20 }
                    PathMove { x: 16; y: 4 }
                    PathLine { x: 16; y: 20 }
                  }
                }
                Shape {
                  anchors.fill: parent
                  visible: !historyRow.isPlaying
                  ShapePath {
                    strokeColor: Colors.text; strokeWidth: 1.8; fillColor: "transparent"
                    capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
                    startX: 8; startY: 5
                    PathLine { x: 18; y: 12 }
                    PathLine { x: 8; y: 19 }
                    PathLine { x: 8; y: 5 }
                  }
                }
                MouseArea { anchors.fill: parent; enabled: !root.busy && modelData.audioAvailable; cursorShape: Qt.PointingHandCursor; onClicked: root.togglePlay(modelData) }
              }
              Text {
                id: timeText
                anchors { left: playButton.right; leftMargin: 16; verticalCenter: playButton.verticalCenter }
                text: (historyRow.isPlaying ? root.fmtDur(root.positionMs) : "0:00")
                  + " / "
                  + ((historyRow.isPlaying && root.durationMs > 0) ? root.fmtDur(root.durationMs)
                    : (modelData.durationMs != null ? root.fmtDur(modelData.durationMs) : "--:--"))
                color: historyRow.isPlaying ? Colors.text : Colors.text_alt
                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12
              }
              PillButton {
                id: retryButton
                anchors { right: parent.right; bottom: parent.bottom }
                width: 104; height: 40
                text: root.busyId === modelData.id && root.busyAction === "retry" ? "Retrying" : (modelData.audioAvailable ? "Retry" : "No audio")
                textSize: 14; emphasized: true; filled: true; inactiveFillColor: Tokens.surfaceContainer
                enabled: !root.busy && modelData.audioAvailable
                onClicked: root.retry(modelData)
              }
            }
            Item {
              visible: historyRow.selected
              anchors.right: parent.right; anchors.rightMargin: 16; anchors.top: parent.top; anchors.topMargin: 20
              width: 24; height: 24
              R1Icon {
                anchors.centerIn: parent
                iconName: "trash"
                font.pixelSize: 18
                color: root.confirmId === modelData.id ? Colors.warning : Colors.text_alt
              }
              MouseArea { anchors.fill: parent; anchors.margins: -8; enabled: !root.busy; onClicked: root.requestDelete(modelData) }
            }
            Row {
              visible: historyRow.selected
              anchors.left: parent.left; anchors.right: parent.right; anchors.leftMargin: 16; anchors.rightMargin: 16; anchors.bottom: parent.bottom; anchors.bottomMargin: 16; spacing: 8
              PillButton { width: 164; height: 40; text: "Copy"; textSize: 14; emphasized: true; outlined: true; enabled: !root.busy; onClicked: root.copy(editor.text) }
              PillButton { width: parent.width - 172; height: 40; text: "Save changes"; textSize: 14; emphasized: true; filled: true; active: true; fillColor: Colors.button; inactiveFillColor: Colors.button; activeTextColor: Colors.on_button; enabled: !root.busy; onClicked: root.save(modelData, editor.text) }
            }
            R1Icon {
              visible: !historyRow.selected
              anchors.left: parent.left; anchors.leftMargin: 16; anchors.verticalCenter: parent.verticalCenter
              glyph: "\uf130"; color: Colors.text_alt; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 18
            }
            Column {
              visible: !historyRow.selected
              anchors.left: parent.left; anchors.leftMargin: 56; anchors.right: parent.right; anchors.rightMargin: 24; anchors.verticalCenter: parent.verticalCenter; spacing: 4
              Text { width: parent.width; text: root.historyTitle(modelData.timestamp); color: Colors.text; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; elide: Text.ElideRight }
              Text { width: parent.width; text: String(modelData.text || "").replace(/\s+/g, " ").trim(); color: Colors.text_alt; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; elide: Text.ElideRight }
            }
            R1Icon { visible: !historyRow.selected; anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; glyph: "\uf054"; color: Colors.text_alt; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 13 }
            MouseArea { anchors.fill: parent; enabled: !historyRow.selected; onClicked: root.selectedHistoryId = modelData.id }
          }
          }
        }
        }

        Component.onCompleted: {
          modelList.x = root.tab === 0 ? 0 : -modelList.width
          historyPage.x = root.tab === 0 ? historyPage.width : 0
          handyPages.pagesReady = true
        }

  bottomContent: Item {
    width: parent.width
    height: root.tab === 0 ? 88 : 18
    Text {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      text: root.busy ? "Updating Handy…" : (root.tab === 0 ? "Selecting a model restarts Handy in the background." : root.history.length + " recent recordings · Select text to edit")
      color: Colors.text_alt
      font.family: "JetBrainsMono Nerd Font"
      font.pixelSize: 12
      elide: Text.ElideRight
      height: root.tab === 0 ? 24 : 18
    }
    PillButton {
      visible: root.tab === 0
      width: parent.width
      anchors.bottom: parent.bottom
      height: 40
      text: "Refresh models"
      filled: true
      active: true
      enabled: !root.busy
      onClicked: root.refresh()
    }
  }
}
