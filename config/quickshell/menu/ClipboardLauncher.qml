import QtQuick
import Quickshell
import Quickshell.Io
import "../components"
import "../launcher/plugin/compat" as CastCompat
import qs

LauncherBase {
  id: root

  sockName: "kmdot-clipboard"
  castStyle: true
  title: "Clipboard"
  searchPlaceholder: "Search clipboard history…"
  headerTitle: root.previewMode ? "Clipboard Preview" : "Clipboard"
  cardHeight: 520
  primaryActionText: root.previewMode ? "Copy image" : "Copy"
  closeOnActivate: false
  footerHint: root.resultCount > 0 ? "↑↓ navigate · ↵ copy" : ""
  footerActionText: root.previewMode || root.loading || root.pool.length === 0 ? "" : "Clear history"
  footerActionVisible: false
  emptyText: root.pool.length === 0 ? "Copy text or an image to see it here." : "No matching entries"
  emptyIconName: "clipboard"
  loadingText: "Loading clipboard…"
  listStatusText: root.previewMode || root.pool.length === 0 ? "" : "History expires after 24 hours"
  listStatusActionText: ""
  listStatusActionWidth: 160
  detailMode: root.previewMode
  searchEnabled: !root.previewMode
  detailContent: imagePreview
  countShown: false

  property bool previewMode: false
  property var previewItem: null

  function fmtTime(epoch) {
    const now = Math.floor(Date.now() / 1000)
    const delta = Math.max(0, now - epoch)
    if (delta < 60) return "Just now"
    if (delta < 3600) {
      const n = Math.floor(delta / 60)
      return n + (n === 1 ? " minute ago" : " minutes ago")
    }
    if (delta < 86400) {
      const n = Math.floor(delta / 3600)
      return n + (n === 1 ? " hour ago" : " hours ago")
    }
    const n = Math.floor(delta / 86400)
    return n + (n === 1 ? " day ago" : " days ago")
  }

  function refreshItems() {
    root.loading = true
    root.pool = []
    listProc.exec(["sh", "-c", "$HOME/.config/kmdot/quickshell/scripts/clipboard-list.sh"])
  }

  function addLine(line) {
    const raw = String(line)
    if (!raw.trim()) return
    const parts = raw.split("\t")
    if (parts.length < 4) return

    const hash = parts[0]
    const type = parts[1]
    const epoch = parseInt(parts[2], 10) || 0
    const isImage = type === "img"
    const snippet = parts[3] || (isImage ? "Image" : "")
    const preview = parts.length > 4 ? parts[4] : ""
    const body = parts.length > 5 ? parts[5] : ""
    const detail = parts.length > 6 ? parts[6] : ""
    const imageSource = parts.length > 7 ? parts[7] : preview

    root.pool = root.pool.concat([{
      hash: hash,
      label: snippet || "(empty)",
      subtitle: (isImage ? "Image" : "Text") + " · " + root.fmtTime(epoch),
      body: body,
      meta: isImage ? "Copy image" : "Copy",
      glyph: isImage ? "" : "\uf0ea",
      icon: isImage ? preview : "",
      imageSource: isImage ? imageSource : "",
      previewSubtitle: isImage && detail
        ? detail.replace(" · ", " · Copied " + root.fmtTime(epoch) + " · ")
        : "PNG image · Copied " + root.fmtTime(epoch),
      isImage: isImage
    }])
  }

  function copyItem(item) {
    if (item && item.hash)
      root.runCommand("$HOME/.config/kmdot/quickshell/scripts/clipboard-copy.sh " + item.hash)
  }

  Process {
    id: listProc
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function(data) { root.addLine(data) }
    }
    onExited: root.loading = false
  }

  Process {
    id: clearProc
    onExited: root.refreshItems()
  }

  onActivated: function(item) {
    if (root.previewMode) {
      root.copyItem(root.previewItem)
      return
    }
    if (item.isImage) {
      root.previewItem = item
      root.previewMode = true
      return
    }
    root.copyItem(item)
    root.closeLauncher()
  }

  onDetailBackRequested: root.previewMode = false
  onDetailAcceptRequested: {
    root.copyItem(root.previewItem)
    root.closeLauncher()
  }

  function onOpenedChange() {
    if (!root.opened) {
      root.previewMode = false
      root.previewItem = null
    }
  }

  onFooterActionClicked: {
    clearProc.exec(["sh", "-c", "$HOME/.config/kmdot/quickshell/scripts/clipboard-clear.sh"])
  }

  Component {
    id: imagePreview

    Item {
      Rectangle {
        id: imageFrame
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 256
        radius: 16
        color: Colors.base

        Rectangle {
          anchors { top: parent.top; left: parent.left; right: parent.right; margins: 16 }
          height: 18
          radius: 9
          color: Colors.surface_high
        }

        Image {
          anchors.centerIn: parent
          width: Math.min(560, parent.width - 48)
          height: 196
          source: root.previewItem ? root.previewItem.imageSource : ""
          fillMode: Image.PreserveAspectFit
          asynchronous: true
        }
      }

      Text {
        anchors { top: imageFrame.bottom; left: parent.left; right: parent.right; topMargin: 14 }
        text: root.previewItem ? root.previewItem.label : "Image"
        font.family: CastCompat.Style.font.menuFamily
        font.pixelSize: 17
        font.weight: Font.DemiBold
        color: Colors.text
        elide: Text.ElideRight
      }

      Text {
        anchors { top: imageFrame.bottom; left: parent.left; right: parent.right; topMargin: 40 }
        text: root.previewItem ? root.previewItem.previewSubtitle : "PNG image"
        font.family: CastCompat.Style.font.menuFamily
        font.pixelSize: 12
        color: Colors.text_alt
        elide: Text.ElideRight
      }

      Rectangle {
        width: 124
        height: 34
        radius: 8
        anchors { right: parent.right; bottom: parent.bottom; bottomMargin: 8 }
        color: Colors.primary

        Text {
          anchors.centerIn: parent
          text: "Copy image"
          font.family: CastCompat.Style.font.menuFamily
          font.pixelSize: 12
          font.weight: Font.DemiBold
          color: Colors.on_primary
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.copyItem(root.previewItem)
            root.closeLauncher()
          }
        }
      }
    }
  }
}
