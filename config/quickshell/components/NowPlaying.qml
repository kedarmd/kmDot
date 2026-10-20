import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell.Services.Mpris
import qs
import "../components"

Item {
  id: root

  width: parent.width
  implicitHeight: 144
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
  readonly property bool timelineAvailable: root.player && root.player.positionSupported
    && root.player.canSeek && root.trackLength > 0
  readonly property real progress: root.timelineAvailable
    ? Math.max(0, Math.min(1, root.positionSeconds / root.trackLength)) : 0
  property real hoverSeconds: 0
  property real seekPendingUntil: 0

  function formatTime(value) {
    const seconds = Math.max(0, Math.floor(Number(value) || 0))
    const minutes = Math.floor(seconds / 60)
    const remainder = String(seconds % 60).padStart(2, "0")
    if (minutes >= 60) return Math.floor(minutes / 60) + ":" + String(minutes % 60).padStart(2, "0") + ":" + remainder
    return minutes + ":" + remainder
  }

  function seekTo(x) {
    if (!root.player || !root.player.canSeek || root.trackLength <= 0) return
    const target = Math.max(0, Math.min(root.trackLength, root.trackLength * x / progressTrack.width))
    if (root.player.positionSupported) root.player.position = target
    else root.player.seek(target - root.positionSeconds)
    root.positionSeconds = target
    root.seekPendingUntil = Date.now() + 1500
  }

  function livePlayer(p) {
    return p && p.trackTitle &&
      (p.isPlaying || p.playbackState === MprisPlaybackState.Paused)
  }

  function timelineScore(p) {
    if (!p) return 0
    return (p.lengthSupported && p.length > 0 ? 4 : 0)
      + (p.positionSupported ? 2 : 0)
      + (p.canSeek ? 1 : 0)
  }

  function pickPlayer() {
    const all = Mpris.players ? Mpris.players.values : []
    const candidates = []
    for (const p of all) {
      if (String(p.dbusName || "").indexOf("org.mpris.MediaPlayer2.playerctld") >= 0) continue
      if (root.livePlayer(p)) candidates.push(p)
    }
    const playing = candidates.filter(p => p.isPlaying)
    const pool = playing.length > 0 ? playing : candidates
    if (pool.length === 0) return null
    let best = pool[0]
    for (let i = 1; i < pool.length; i++) {
      if (root.timelineScore(pool[i]) > root.timelineScore(best)) best = pool[i]
    }
    if (root.player && pool.indexOf(root.player) >= 0 && root.timelineScore(root.player) >= root.timelineScore(best))
      return root.player
    return best
  }

  Timer {
    interval: 1000
    repeat: true
    running: true
    onTriggered: {
      const selected = root.pickPlayer()
      if (selected !== root.player) root.player = selected
      if (!root.player) return
      // MprisPlayer deliberately suppresses automatic positionChanged signals
      // to avoid needless updates. Request one while playing so consumers see
      // the current position, then poll it for the compact progress display.
      if (root.player.isPlaying && root.player.positionSupported) root.player.positionChanged()
      if (Date.now() >= root.seekPendingUntil) root.positionSeconds = root.player.position
    }
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
          border.color: Colors.outline_variant
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
    y: 64
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
    y: 112
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
    Rectangle {
      visible: progressArea.containsMouse && root.timelineAvailable
      z: 2
      x: Math.max(0, Math.min(progressTrack.width - width, root.hoverSeconds / root.trackLength * progressTrack.width - width / 2))
      y: -25
      width: hoverTime.implicitWidth + 16
      height: 20
      radius: 8
      color: Colors.surface_highest
      border.width: 1
      border.color: Colors.border
      Text {
        id: hoverTime
        anchors.centerIn: parent
        text: root.formatTime(root.hoverSeconds)
        color: Colors.text
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 11
      }
    }
    MouseArea {
      id: progressArea
      x: 0
      y: -8
      width: parent.width
      height: parent.height + 16
      hoverEnabled: true
      enabled: root.timelineAvailable
      cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
      onPositionChanged: {
        root.hoverSeconds = root.trackLength * Math.max(0, Math.min(1, mouse.x / width))
        if (pressed) root.seekTo(mouse.x)
      }
      onPressed: root.seekTo(mouse.x)
      onEntered: root.hoverSeconds = root.trackLength * Math.max(0, Math.min(1, mouseX / width))
    }
  }

  Item {
    x: 0
    y: 122
    width: root.width
    height: 16
    Text {
      text: root.timelineAvailable ? root.formatTime(root.positionSeconds) : "--:--"
      color: Colors.text_alt
      font.family: "JetBrainsMono Nerd Font"
      font.pixelSize: 11
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
    }
    Text {
      text: root.trackLength > 0 ? root.formatTime(root.trackLength) : "--:--"
      color: Colors.text_alt
      font.family: "JetBrainsMono Nerd Font"
      font.pixelSize: 11
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
    }
  }
}
