import QtQuick
import Quickshell
import Quickshell.Io
import qs
import "../components"

PopupBase {
  id: root
  sockName: "kmdot-handy"
  cardWidth: 500

  property int tab: 0
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
  readonly property real listHeight: 440
  // Two-click delete confirm: first click arms the row's pill ("Sure?"), the
  // second (within 3s) deletes.
  property int confirmId: -1

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
  function fmtDur(ms) {
    const total = Math.max(0, Math.floor(Number(ms || 0) / 1000))
    return Math.floor(total / 60) + ":" + String(total % 60).padStart(2, "0")
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
      if (root.confirmId < 0) return
      for (let i = 0; i < HandyStore.history.length; i++) {
        if (HandyStore.history[i].id === root.confirmId) return
      }
      root.confirmId = -1
    }
  }
  Process { id: copyProc }

        Item {
          width: parent.width; height: 34
          Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "\uf130"; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 23; color: Colors.primary }
          Text { anchors.left: parent.left; anchors.leftMargin: 34; anchors.verticalCenter: parent.verticalCenter; text: "Handy"; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 16; font.weight: Font.DemiBold; color: Colors.text }
          Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: root.busy ? "Working" : (root.tab === 0 ? "Models" : "History"); font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 12; color: Colors.muted }
        }

        Row {
          width: parent.width; spacing: 8
          PillButton { width: (parent.width - 8) / 2; text: "Models"; active: root.tab === 0; onClicked: root.tab = 0 }
          PillButton { width: (parent.width - 8) / 2; text: "History"; active: root.tab === 1; onClicked: root.tab = 1 }
        }
        Text { visible: root.effectiveError !== ""; width: parent.width; text: root.effectiveError; color: Colors.error; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 12; wrapMode: Text.WordWrap }

        ListView {
          id: modelList
          visible: root.tab === 0
          width: parent.width
          height: root.listHeight
          spacing: 6
          clip: true
          interactive: contentHeight > height
          model: root.models
          delegate: Rectangle {
            required property var modelData
            width: modelList.width - 8; height: 52; radius: 8
            color: modelData.id === root.selectedModel ? Tokens.primaryContainer : Tokens.surfaceContainerHighest
            Text { anchors.left: parent.left; anchors.leftMargin: 12; anchors.right: check.left; anchors.top: parent.top; anchors.topMargin: 8; text: modelData.name; color: modelData.id === root.selectedModel ? Tokens.on_primary_container : Colors.text; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 12; font.weight: modelData.id === root.selectedModel ? Font.DemiBold : Font.Normal; elide: Text.ElideRight }
            Text { anchors.left: parent.left; anchors.leftMargin: 12; anchors.right: check.left; anchors.bottom: parent.bottom; anchors.bottomMargin: 7; text: modelData.engine; color: modelData.id === root.selectedModel ? Tokens.on_primary_container : Colors.muted; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 10; elide: Text.ElideRight }
            Text { id: check; anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; text: modelData.id === root.selectedModel ? "\uf00c" : ""; color: Tokens.on_primary_container; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 14 }
            MouseArea { anchors.fill: parent; enabled: !root.busy; onClicked: root.selectModel(modelData.id) }
          }
        }

        ListView {
          id: historyList
          visible: root.tab === 1
          width: parent.width
          height: root.listHeight
          spacing: 8
          clip: true
          interactive: contentHeight > height
          model: root.history
          delegate: Rectangle {
            id: historyRow
            required property var modelData
            readonly property bool isPlaying: root.playingId === modelData.id
            width: historyList.width - 8; height: Math.max(editor.implicitHeight, 36) + (modelData.audioAvailable ? 76 : 44); radius: 8
            color: Tokens.surfaceContainerHighest
            Text {
              anchors.left: parent.left; anchors.leftMargin: 10; anchors.verticalCenter: actionsRow.verticalCenter
              text: root.fmtTime(modelData.timestamp); color: Colors.text_alt; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 10; width: 105; elide: Text.ElideRight
            }
            Row {
              id: actionsRow
              anchors.right: parent.right; anchors.rightMargin: 10; anchors.top: parent.top; anchors.topMargin: 7; spacing: 8
              PillButton { width: 62; height: 24; text: "Save"; glyph: "\uf0c7"; glyphSize: 10; textSize: 10; enabled: !root.busy; onClicked: root.save(modelData, editor.text) }
              PillButton { width: 66; height: 24; text: "Copy"; glyph: "\uf0c5"; glyphSize: 10; textSize: 10; enabled: !root.busy; onClicked: root.copy(editor.text) }
              PillButton { width: 84; height: 24; text: root.busyId === modelData.id && root.busyAction === "retry" ? "Retrying" : (modelData.audioAvailable ? "Retry" : "No audio"); glyph: modelData.audioAvailable ? "\uf2f1" : "\uf071"; glyphSize: 10; textSize: 10; enabled: !root.busy && modelData.audioAvailable; onClicked: root.retry(modelData) }
              PillButton {
                width: 62; height: 24
                readonly property bool armed: root.confirmId === modelData.id
                readonly property bool deleting: root.busyId === modelData.id && root.busyAction === "delete"
                text: deleting ? "Deleting" : (armed ? "Sure?" : "Delete")
                glyph: deleting ? "\uf110" : (armed ? "\uf071" : "\uf2ed")
                glyphSize: 10; textSize: 10
                active: armed
                enabled: !root.busy
                onClicked: {
                  if (armed) { confirmTimer.stop(); root.remove(modelData) }
                  else { root.confirmId = modelData.id; confirmTimer.restart() }
                }
              }
            }
            TextEdit {
              id: editor
              anchors.left: parent.left; anchors.leftMargin: 10; anchors.right: parent.right; anchors.rightMargin: 10; anchors.top: actionsRow.bottom; anchors.topMargin: 5
              width: parent.width - 20; height: Math.max(36, implicitHeight); text: modelData.text; color: Colors.text; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 12; wrapMode: TextEdit.Wrap; selectByMouse: true; persistentSelection: true
              readOnly: root.busy && root.busyId !== modelData.id
            }
            Item {
              visible: modelData.audioAvailable
              anchors { left: parent.left; right: parent.right; margins: 10; top: editor.bottom; topMargin: 7 }
              height: 24
              PillButton {
                id: playButton
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                width: 30; height: 24; active: historyRow.isPlaying
                glyph: historyRow.isPlaying ? "\uf04d" : "\uf04b"; glyphSize: 11
                enabled: !root.busy && modelData.audioAvailable
                onClicked: root.togglePlay(modelData)
              }
              Text {
                id: timeText
                anchors { left: playButton.right; leftMargin: 8; verticalCenter: parent.verticalCenter }
                width: 78
                horizontalAlignment: Text.AlignHCenter
                text: (historyRow.isPlaying ? root.fmtDur(root.positionMs) : "0:00")
                  + " / "
                  + ((historyRow.isPlaying && root.durationMs > 0) ? root.fmtDur(root.durationMs)
                    : (modelData.durationMs != null ? root.fmtDur(modelData.durationMs) : "--:--"))
                color: historyRow.isPlaying ? Colors.text : Colors.text_alt
                font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 10
              }
              Rectangle {
                anchors { left: timeText.right; leftMargin: 8; right: parent.right; verticalCenter: parent.verticalCenter }
                height: 6; radius: 3; color: Colors.muted
                Rectangle {
                  anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                  width: parent.width * (historyRow.isPlaying ? root.progress : 0)
                  radius: 3; color: Colors.primary
                  Behavior on width { NumberAnimation { duration: 120 } }
                }
              }
            }
          }
        }

        Item {
          width: parent.width; height: 24
          Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: root.busy ? "Updating Handy…" : (root.tab === 0 ? root.models.length + " installed model(s)" : root.history.length + " recent recording(s)"); color: Colors.muted; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 10 }
          PillButton { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: 72; height: 24; text: "Refresh"; glyph: "\uf021"; glyphSize: 10; textSize: 10; enabled: !root.busy; onClicked: root.refresh() }
        }
}
