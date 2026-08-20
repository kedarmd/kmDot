import QtQuick
import Quickshell.Services.Mpris
import qs
import "../components"

Item {
  id: root

  width: parent.width
  implicitHeight: col.implicitHeight
  visible: root.player !== null

  property var player: null

  readonly property string title: root.player ? root.player.trackTitle : ""
  readonly property string artist: root.player ? root.player.trackArtist : ""
  readonly property string album: root.player ? root.player.trackAlbum : ""
  property string videoId: ""
  property bool maxresMissing: false

  readonly property string artUrl: {
    if (root.player) {
      if (root.player.trackArtUrl) return root.player.trackArtUrl
      const meta = root.player.metadata || {}
      const url = String(meta["xesam:url"] || "")
      const m = /(?:youtube\.com\/watch\?v=|youtu\.be\/)([A-Za-z0-9_-]{11})/.exec(url)
      if (m) {
        root.videoId = m[1]
        return "https://i.ytimg.com/vi/" + m[1] + "/maxresdefault.jpg"
      }
    }
    root.videoId = ""
    return ""
  }

  readonly property string hqArtUrl:
    root.videoId !== "" ? "https://i.ytimg.com/vi/" + root.videoId + "/hqdefault.jpg" : ""
  readonly property bool playing: root.player ? root.player.isPlaying : false
  readonly property bool canPrev: root.player ? (root.player.canControl && root.player.canGoPrevious) : false
  readonly property bool canNext: root.player ? (root.player.canControl && root.player.canGoNext) : false
  readonly property bool canToggle: root.player ? root.player.canTogglePlaying : false
  readonly property bool showArt: root.artUrl !== ""

  readonly property real artHeight:
    titleLine.implicitHeight +
    (root.artist !== "" ? textCol.spacing + artistLine.implicitHeight : 0) +
    textCol.spacing +
    controlsRow.implicitHeight

  function livePlayer(p) {
    return p && p.trackTitle &&
      (p.isPlaying || p.playbackState === MprisPlaybackState.Paused)
  }

  function pickPlayer() {
    const all = Mpris.players ? Mpris.players.values : []
    const candidates = []
    for (const p of all) {
      if (String(p.dbusName || "").indexOf("org.mpris.MediaPlayer2.playerctld") >= 0) continue
      if (root.livePlayer(p)) candidates.push(p)
    }
    const playing = candidates.filter(p => p.isPlaying)
    if (playing.length > 0) {
      if (root.player && playing.indexOf(root.player) >= 0) return root.player
      return playing[0]
    }
    if (root.player && candidates.indexOf(root.player) >= 0) return root.player
    return candidates.length > 0 ? candidates[0] : null
  }

  Timer {
    interval: 2000
    repeat: true
    running: true
    onTriggered: root.player = root.pickPlayer()
  }
  Component.onCompleted: root.player = root.pickPlayer()

  Column {
    id: col
    width: root.width
    spacing: 8

    Text {
      text: "Now playing"
      font.family: "JetBrainsMono Nerd Font Propo"
      font.pixelSize: 12
      color: Colors.muted
    }

    Row {
      id: bodyRow
      width: col.width
      spacing: 12

      Image {
        id: art
        width: root.artHeight
        height: root.artHeight
        visible: root.showArt
        source: root.maxresMissing ? root.hqArtUrl : root.artUrl
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(256, 256)
        onStatusChanged: {
          if (status === Image.Ready && !root.maxresMissing && root.videoId !== "" &&
              art.implicitWidth > 0 && (art.implicitWidth / art.implicitHeight) < 1.5) {
            root.maxresMissing = true
          }
        }
      }

      Column {
        id: textCol
        width: bodyRow.width - root.artHeight - bodyRow.spacing
        spacing: 3

        Text {
          id: titleLine
          width: parent.width
          text: root.album !== "" ? root.title + " · " + root.album : root.title
          font.family: "JetBrainsMono Nerd Font Propo"
          font.pixelSize: 13
          font.weight: Font.DemiBold
          color: Colors.text
          elide: Text.ElideRight
        }

        Text {
          id: artistLine
          width: parent.width
          visible: root.artist !== ""
          text: root.artist
          font.family: "JetBrainsMono Nerd Font Propo"
          font.pixelSize: 12
          color: Colors.text_alt
          elide: Text.ElideRight
        }

        Row {
          id: controlsRow
          spacing: 6

          PillButton {
            width: 30
            height: 30
            enabled: root.canPrev
            glyph: "\uf048"
            glyphSize: 12
            onClicked: if (root.player) root.player.previous()
          }

          PillButton {
            width: 30
            height: 30
            enabled: root.canToggle
            active: root.playing
            glyph: root.playing ? "\uf04c" : "\uf04b"
            glyphSize: 12
            onClicked: if (root.player) root.player.togglePlaying()
          }

          PillButton {
            width: 30
            height: 30
            enabled: root.canNext
            glyph: "\uf051"
            glyphSize: 12
            onClicked: if (root.player) root.player.next()
          }
        }
      }
    }
  }
}
