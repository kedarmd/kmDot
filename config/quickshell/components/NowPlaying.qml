import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell.Services.Mpris
import qs
import "../components"

Item {
  id: root

  width: parent.width
  implicitHeight: 128
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

  readonly property real artHeight: 72
  property real positionSeconds: 0
  readonly property real trackLength: root.player && root.player.lengthSupported ? root.player.length : 0
  readonly property real progress: root.trackLength > 0 ? Math.max(0, Math.min(1, root.positionSeconds / root.trackLength)) : 0

  function seekTo(x) {
    if (!root.player || !root.player.canSeek || root.trackLength <= 0) return
    const target = Math.max(0, Math.min(root.trackLength, root.trackLength * x / progressTrack.width))
    if (root.player.positionSupported) root.player.position = target
    else root.player.seek(target - root.positionSeconds)
    root.positionSeconds = target
  }

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
    interval: 1000
    repeat: true
    running: true
    onTriggered: root.player = root.pickPlayer()
  }
  Component.onCompleted: {
    root.player = root.pickPlayer()
    root.positionSeconds = root.player ? root.player.position : 0
  }
  onPlayerChanged: root.positionSeconds = root.player ? root.player.position : 0

  Item {
    id: disc
    x: 0
    y: 0
    width: root.artHeight
    height: root.artHeight
    transformOrigin: Item.Center

        Item {
          id: fallbackDisc
          anchors.fill: parent
          visible: !disc.artImageReady
          Rectangle { anchors.fill: parent; radius: 16; color: Tokens.primaryContainer }
          R1Icon { anchors.centerIn: parent; glyph: "\uf001"; font.family: "JetBrainsMono Nerd Font Propo"; font.pixelSize: 24; color: Colors.primary }
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
            radius: 16
            color: "white"
          }
        }

        Rectangle {
          anchors.fill: parent
          radius: 16
          color: "transparent"
          border.width: 1
          border.color: Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, 0.24)
        }

  }

  Text {
    id: titleLine
    x: 88
    y: 0
    width: root.width - 88
    height: 30
    text: root.title
    font.family: "JetBrainsMono Nerd Font"
    font.pixelSize: 20
    font.weight: Font.DemiBold
    color: Colors.text
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
  }

  Text {
    id: artistLine
    x: 88
    y: 34
    width: root.width - 88
    height: 18
    visible: root.artist !== "" || root.album !== ""
    text: root.artist + (root.artist !== "" && root.album !== "" ? " · " : "") + root.album
    font.family: "JetBrainsMono Nerd Font"
    font.pixelSize: 12
    color: Colors.text_alt
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
  }

  Row {
    x: 88
    y: 78
    width: 144
    height: 24
    spacing: 36

    Repeater {
      model: [
        { glyph: "\uf048", enabled: root.canPrev, act: "previous" },
        { glyph: root.playing ? "\uf04c" : "\uf04b", enabled: root.canToggle, act: "toggle" },
        { glyph: "\uf051", enabled: root.canNext, act: "next" }
      ]
      delegate: Item {
        required property var modelData
        width: 24
        height: 24
        opacity: modelData.enabled ? 1 : 0.45
        R1Icon {
          anchors.centerIn: parent
          glyph: modelData.glyph
          color: Colors.text
          font.family: "JetBrainsMono Nerd Font Propo"
          font.pixelSize: 16
        }
        MouseArea {
          anchors.fill: parent
          enabled: modelData.enabled
          cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
          onClicked: {
            if (!root.player) return
            if (modelData.act === "previous") root.player.previous()
            else if (modelData.act === "next") root.player.next()
            else root.player.togglePlaying()
          }
        }
      }
    }
  }

  Rectangle {
    id: progressTrack
    x: 0
    y: 122
    width: root.width
    height: 4
    radius: 2
    color: Tokens.outlineVariant
    Rectangle {
      width: parent.width * root.progress
      height: parent.height
      radius: parent.radius
      color: Colors.primary
    }
    MouseArea {
      x: 0
      y: -8
      width: parent.width
      height: parent.height + 16
      enabled: root.player && root.player.canSeek && root.trackLength > 0
      cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
      onPressed: root.seekTo(mouse.x)
      onPositionChanged: if (pressed) root.seekTo(mouse.x)
    }
  }
}
