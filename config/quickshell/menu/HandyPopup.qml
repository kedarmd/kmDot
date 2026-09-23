import QtQuick
import Quickshell
import Quickshell.Io
import QtMultimedia
import qs
import "../components"

PopupBase {
  id: root
  sockName: "kmdot-handy"
  cardWidth: 500

  property int tab: 0
  // Read path served by the HandyStore singleton (issue #52): the popup binds
  // its models/history/selection here instead of fetching them itself.
  // Mutations, playback, and busy/error for those stay view-local.
  property var models: HandyStore.models
  property var history: HandyStore.history
  property string selectedModel: HandyStore.selectedModel
  property string errorText: ""
  // Mutation errors (local) take precedence; fetch errors come from the store.
  readonly property string effectiveError: root.errorText !== "" ? root.errorText : HandyStore.errorText
  property int busyId: -1
  property string busyAction: ""
  readonly property bool busy: busyAction !== ""
  readonly property real listHeight: 440
  property int playingId: -1
  property real progress: 0
  property bool playbackStopping: false
  // Two-click delete confirm: first click arms the row's pill ("Sure?"), the
  // second (within 3s) deletes.
  property int confirmId: -1
  readonly property string recordingsDir: Quickshell.env("HOME") + "/.local/share/com.pais.handy/recordings"

  function script() { return Quickshell.env("HOME") + "/.config/kmdot/quickshell/scripts/handy-control.mjs" }
  function run(command, args) {
    controlProc.exec(["node", script(), command].concat(args || []))
  }
  function refreshItems() { refresh() }
  function openedChange() {
    if (!root.opened) {
      stopPlayback()
      confirmId = -1
      busyAction = ""
      busyId = -1
    }
  }
  function refresh() {
    stopPlayback()
    confirmId = -1
    errorText = ""
    HandyStore.refresh()
  }
  function remove(row) {
    if (playingId === row.id) stopPlayback()
    busyId = row.id
    busyAction = "delete"
    run("delete", [String(row.id)])
  }
  function fmtTime(epoch) {
    return new Date(epoch * 1000).toLocaleString(undefined, { month: "short", day: "numeric", hour: "numeric", minute: "2-digit" })
  }
  function fmtDur(ms) {
    const total = Math.max(0, Math.floor(Number(ms || 0) / 1000))
    return Math.floor(total / 60) + ":" + String(total % 60).padStart(2, "0")
  }
  function syncProgress() {
    progress = playingId >= 0 && player.duration > 0 ? Math.min(1, player.position / player.duration) : 0
  }
  function stopPlayback() {
    playingId = -1
    progress = 0
    if (player.playbackState === MediaPlayer.PlayingState || player.source.toString() !== "") {
      playbackStopping = true
      player.stop()
      player.source = ""
      playbackStopping = false
    }
  }
  function togglePlay(row) {
    if (playingId === row.id) { stopPlayback(); return }
    if (!row.audioAvailable) return
    playingId = row.id
    progress = 0
    errorText = ""
    playbackStopping = true
    player.stop()
    player.source = "file://" + recordingsDir + "/" + row.fileName
    playbackStopping = false
    player.play()
  }
  function applyResult(text) {
    try {
      const result = JSON.parse(String(text))
      if (!result.ok) { errorText = result.error || "Handy operation failed"; return }
      // Reads live in HandyStore; mutations update it here. Save returns
      // { ok: true } with no payload, so like before it refetches nothing.
      // Retry keeps the old refresh() side effects (stop playback, reset
      // confirm/error) with the fetch itself routed through the store.
      if (result.selected) HandyStore.selectedModel = result.selected
      if (result.deleted !== undefined) { confirmId = -1; HandyStore.refresh() }
      if (result.text !== undefined) { stopPlayback(); confirmId = -1; errorText = ""; HandyStore.refresh() }
    } catch (e) { errorText = "Could not parse Handy response" }
  }
  function selectModel(id) { busyAction = "model"; run("select-model", [id]) }
  function retry(row) { busyId = row.id; busyAction = "retry"; run("retry", [String(row.id), selectedModel]) }
  function save(row, text) { busyId = row.id; busyAction = "save"; run("save", [String(row.id), text]) }
  function copy(text) { copyProc.exec(["sh", "-c", "printf '%s' \"$1\" | wl-copy", "kmdot", text]) }

  Timer {
    id: confirmTimer
    interval: 3000
    onTriggered: root.confirmId = -1
  }
  Process {
    id: controlProc
    stdout: StdioCollector {
      onStreamFinished: {
        root.applyResult(String(this.text))
        root.busyAction = ""
        root.busyId = -1
      }
    }
  }
  Process { id: copyProc }
  MediaPlayer {
    id: player
    audioOutput: AudioOutput {}
    onPositionChanged: root.syncProgress()
    onDurationChanged: root.syncProgress()
    onPlaybackStateChanged: if (playbackState === MediaPlayer.StoppedState && !root.playbackStopping) root.stopPlayback()
    onErrorOccurred: {
      if (root.playingId >= 0) root.errorText = "Could not play recording"
      root.stopPlayback()
    }
  }

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
                text: (historyRow.isPlaying ? root.fmtDur(player.position) : "0:00")
                  + " / "
                  + ((historyRow.isPlaying && player.duration > 0) ? root.fmtDur(player.duration)
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
