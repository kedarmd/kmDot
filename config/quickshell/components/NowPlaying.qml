import QtQuick
import Qt5Compat.GraphicalEffects
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
  property bool maxresMissing: false

  readonly property string youtubeVideoId: {
    const meta = root.player ? (root.player.metadata || {}) : {}
    const url = String(meta["xesam:url"] || "")
    const m = /(?:youtube\.com\/watch\?v=|youtu\.be\/)([A-Za-z0-9_-]{11})/.exec(url)
    return m ? m[1] : ""
  }

  readonly property string artUrl: {
    if (root.player) {
      const direct = String(root.player.trackArtUrl || "")
      if (direct !== "") return direct
      if (root.youtubeVideoId !== "") {
        return "https://i.ytimg.com/vi/" + root.youtubeVideoId + "/maxresdefault.jpg"
      }
    }
    return ""
  }

  readonly property string hqArtUrl:
    root.youtubeVideoId !== "" ? "https://i.ytimg.com/vi/" + root.youtubeVideoId + "/hqdefault.jpg" : ""
  readonly property bool playing: root.player ? root.player.isPlaying : false
  readonly property bool canPrev: root.player ? (root.player.canControl && root.player.canGoPrevious) : false
  readonly property bool canNext: root.player ? (root.player.canControl && root.player.canGoNext) : false
  readonly property bool canToggle: root.player ? root.player.canTogglePlaying : false
  readonly property bool showArt: root.artUrl !== ""

  onArtUrlChanged: root.maxresMissing = false

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

      Item {
        id: disc
        width: root.artHeight
        height: root.artHeight
        transformOrigin: Item.Center

        Timer {
          interval: 16
          repeat: true
          running: root.playing
          onTriggered: {
            if (root.playing) disc.rotation = (disc.rotation + 0.6) % 360
          }
        }

        Canvas {
          id: fallbackDisc
          anchors.fill: parent
          visible: !disc.artImageReady

          onPaint: {
            const ctx = getContext("2d")
            const cx = width / 2
            const cy = height / 2
            const radius = Math.min(width, height) / 2 - 1
            ctx.clearRect(0, 0, width, height)

            const gradient = ctx.createRadialGradient(cx, cy, radius * 0.08,
                                                       cx, cy, radius)
            gradient.addColorStop(0, Colors.primary_alt)
            gradient.addColorStop(0.48, Colors.primary)
            gradient.addColorStop(1, Colors.surface_alt)
            ctx.fillStyle = gradient
            ctx.beginPath()
            ctx.arc(cx, cy, radius, 0, Math.PI * 2)
            ctx.fill()

            ctx.strokeStyle = Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, 0.22)
            ctx.lineWidth = 1
            for (let i = 1; i < 5; i++) {
              ctx.beginPath()
              ctx.arc(cx, cy, radius * (0.25 + i * 0.13), 0, Math.PI * 2)
              ctx.stroke()
            }

            ctx.fillStyle = Colors.base
            ctx.beginPath()
            ctx.arc(cx, cy, Math.max(4, radius * 0.12), 0, Math.PI * 2)
            ctx.fill()
            ctx.strokeStyle = Colors.text
            ctx.globalAlpha = 0.7
            ctx.beginPath()
            ctx.arc(cx, cy, Math.max(2, radius * 0.045), 0, Math.PI * 2)
            ctx.stroke()
            ctx.globalAlpha = 1
          }
        }

        Image {
          id: artImage
          anchors.fill: parent
          visible: false
          source: root.maxresMissing ? root.hqArtUrl : root.artUrl
          fillMode: Image.PreserveAspectCrop
          sourceSize: Qt.size(256, 256)
          onStatusChanged: {
            if (status === Image.Ready && !root.maxresMissing && root.youtubeVideoId !== "" &&
                artImage.implicitWidth > 0 &&
                (artImage.implicitWidth / artImage.implicitHeight) < 1.5) {
              root.maxresMissing = true
            } else if (status === Image.Error && !root.maxresMissing && root.youtubeVideoId !== "") {
              root.maxresMissing = true
            }
          }
        }

        readonly property bool artImageReady: root.showArt && artImage.status === Image.Ready

        OpacityMask {
          anchors.fill: parent
          visible: disc.artImageReady
          source: artImage
          maskSource: Rectangle {
            width: disc.width
            height: disc.height
            radius: width / 2
            color: "white"
          }
        }

        Rectangle {
          anchors.fill: parent
          radius: width / 2
          color: "transparent"
          border.width: 1
          border.color: Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, 0.24)
        }

        Rectangle {
          anchors.centerIn: parent
          width: Math.max(8, parent.width * 0.16)
          height: width
          radius: width / 2
          color: Colors.base
          border.width: 1
          border.color: Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, 0.55)
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
          width: parent.width
          spacing: 6

          PillButton {
            width: (controlsRow.width - controlsRow.spacing * 2) / 3
            height: 30
            enabled: root.canPrev
            filled: true
            active: true
            fillColor: Tokens.surfaceContainerHighest
            activeTextColor: Colors.text
            glyph: "\uf048"
            glyphSize: 12
            onClicked: if (root.player) root.player.previous()
          }

          PillButton {
            width: (controlsRow.width - controlsRow.spacing * 2) / 3
            height: 30
            enabled: root.canToggle
            filled: true
            active: root.playing
            fillColor: Tokens.primaryContainer
            inactiveFillColor: Tokens.surfaceContainerHighest
            activeTextColor: root.playing ? Tokens.on_primary_container : Colors.text
            glyph: root.playing ? "\uf04c" : "\uf04b"
            glyphSize: 12
            onClicked: if (root.player) root.player.togglePlaying()
          }

          PillButton {
            width: (controlsRow.width - controlsRow.spacing * 2) / 3
            height: 30
            enabled: root.canNext
            filled: true
            active: true
            fillColor: Tokens.surfaceContainerHighest
            activeTextColor: Colors.text
            glyph: "\uf051"
            glyphSize: 12
            onClicked: if (root.player) root.player.next()
          }
        }
      }
    }
  }
}
