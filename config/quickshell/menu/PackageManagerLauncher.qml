import QtQuick
import Quickshell
import Quickshell.Io
import "../components"
import qs

LauncherBase {
  id: root

  required property bool uninstallMode
  sockName: uninstallMode ? "kmdot-package-remove" : "kmdot-package-install"
  castStyle: true
  title: uninstallMode ? "Search installed packages…" : "Search official packages…"
  searchPlaceholder: title
  headerTitle: uninstallMode ? "Remove Packages" : "Install Packages"
  cardHeight: 620
  footerHint: uninstallMode
    ? "↑↓ select · ↵ remove package · Esc close"
    : "↑↓ select · ↵ install package · official repositories only"
  countShown: true
  countNoun: "package"
  emptyText: uninstallMode ? "No installed packages" : "No official packages found"
  loadingText: "Reading Pacman package database…"
  loading: false
  bodyContent: packageBrowser

  property string operationStatus: ""
  property string operationError: ""
  property var info: ({})
  property string infoPackage: ""
  property string infoError: ""
  property var pendingInfoItem: null
  readonly property bool infoReady: !!root.selectedItem && root.infoPackage === root.selectedItem.name
    && !!root.info.Description
  property var pendingRows: []

  readonly property string helper: decodeURIComponent(Qt.resolvedUrl("../scripts/package-manager.sh").toString().replace("file://", ""))

  function refreshItems() {
    root.loading = true
    root.pendingRows = []
    root.pool = []
    listProc.exec([root.helper, root.uninstallMode ? "list-remove" : "list-install"])
  }

  function loadInfo(item) {
    if (!item) return
    if (infoProc.running) {
      root.pendingInfoItem = item
      return
    }
    if (root.infoPackage === item.name) return
    root.infoPackage = item.name
    root.info = ({})
    root.infoError = ""
    infoProc.exec(root.uninstallMode
      ? [root.helper, "info-remove", item.name]
      : [root.helper, "info-install", item.repo, item.name])
  }

  function runOperation(item) {
    if (!item) return
    root.operationStatus = ""
    root.operationError = ""
    root.operationStatus = (root.uninstallMode ? "Removing " : "Installing ") + item.name + "…"
    operationProc.exec(root.uninstallMode
      ? [root.helper, "remove", item.name]
      : [root.helper, "install", item.repo, item.name])
  }

  onSelectedItemChanged: {
    const item = root.selectedItem
    if (item && !root.loading) root.loadInfo(item)
  }
  onActivated: function(item) { root.runOperation(item) }

  Process {
    id: listProc
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function(line) {
        const columns = String(line).replace(/[\r\n]+$/, "").split("\t")
        if (columns.length < 2 || !columns[0]) return
        if (root.uninstallMode) {
          root.pendingRows.push({ name: columns[0], label: columns[0], subtitle: "Installed · " + columns[1], version: columns[1], glyph: "\uf1b2" })
        } else {
          root.pendingRows.push({ name: columns[0], label: columns[0], subtitle: columns[1] + " · " + columns[2], version: columns[1], repo: columns[2], installed: columns[3] === "installed", glyph: "\uf1b2" })
        }
      }
    }
    onExited: function(code) {
      if (code !== 0) root.operationError = "Pacman could not read the package database."
      root.pool = root.pendingRows.sort((a, b) => a.name.localeCompare(b.name))
      root.selectedIndex = 0
      root.infoPackage = ""
      root.loading = false
      if (root.selectedItem) root.loadInfo(root.selectedItem)
    }
  }

  Process {
    id: infoProc
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function(line) {
        const row = String(line).replace(/[\r\n]+$/, "")
        const separator = row.indexOf(":")
        if (separator < 0) return
        const next = Object.assign({}, root.info)
        next[row.slice(0, separator).trim()] = row.slice(separator + 1).trim()
        root.info = next
      }
    }
    stderr: SplitParser {
      splitMarker: "\n"
      onRead: function(line) {
        const message = String(line).trim()
        if (message) root.infoError += message + " "
      }
    }
    onExited: function(code) {
      if (root.pendingInfoItem) {
        const nextItem = root.pendingInfoItem
        root.pendingInfoItem = null
        root.loadInfo(nextItem)
        return
      }
      if (code !== 0 && !root.infoError) root.infoError = "Pacman metadata is unavailable for this package."
      else if (code === 0 && !root.info.Description) root.infoError = "Pacman returned no package description."
      else root.infoError = ""
    }
  }

  Process {
    id: operationProc
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function(line) {
        const message = String(line).trim()
        if (message) root.operationStatus = message
      }
    }
    stderr: SplitParser {
      splitMarker: "\n"
      onRead: function(line) { root.operationError += String(line).trim() + " " }
    }
    onExited: function(code) {
      if (code === 0) root.operationStatus = "Pacman terminal opened. Complete the transaction there, then reopen this launcher to refresh."
      else {
        root.operationStatus = "Transaction failed or was cancelled."
        if (!root.operationError) root.operationError = "Check the Pacman or polkit message for details."
      }
      root.refreshItems()
    }
  }

  Component {
    id: packageBrowser
    Row {
      anchors.fill: parent
      spacing: 12

      Rectangle {
        width: parent.width * 0.53
        height: parent.height
        radius: 14
        color: Colors.base
        clip: true

        ListView {
          id: packageRows
          anchors.fill: parent
          anchors.margins: 7
          clip: true
          model: root.results
          currentIndex: root.selectedIndex
          boundsBehavior: Flickable.StopAtBounds
          delegate: Rectangle {
            required property var modelData
            required property int index
            width: packageRows.width
            height: 54
            radius: 10
            color: root.selectedIndex === index ? Colors.primary_container : "transparent"
            Column {
              anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 12; rightMargin: 10 }
              spacing: 3
              Text {
                width: parent.width
                text: modelData.item.name
                elide: Text.ElideRight
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 14
                font.weight: Font.DemiBold
                color: root.selectedIndex === index ? Colors.on_primary_container : Colors.text
              }
              Text {
                width: parent.width
                text: modelData.item.subtitle
                elide: Text.ElideRight
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
                color: root.selectedIndex === index ? Colors.on_primary_container : Colors.text_alt
              }
            }
            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              onEntered: root.selectedIndex = index
              onClicked: root.activateAt(index)
            }
          }
        }
      }

      Rectangle {
        width: parent.width - parent.width * 0.53 - 12
        height: parent.height
        radius: 14
        color: Colors.base
        clip: true
        Flickable {
          anchors.fill: parent
          anchors.margins: 16
          contentWidth: width
          contentHeight: detailColumn.implicitHeight
          clip: true
          Column {
            id: detailColumn
            width: parent.width
            spacing: 11
            Text {
              width: parent.width
              text: root.selectedItem ? root.selectedItem.name : "Package details"
              wrapMode: Text.WrapAnywhere
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 17
              font.weight: Font.DemiBold
              color: Colors.text
            }
            Text {
              width: parent.width
              text: root.infoReady ? root.info.Description
                : (root.infoError || "Loading package description…")
              wrapMode: Text.Wrap
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 12
              color: !root.infoReady && root.infoError ? Tokens.errorText : Colors.text_alt
            }
            Rectangle { width: parent.width; height: 1; color: Tokens.divider }
            Repeater {
              model: [
                ["Version", (root.infoReady ? root.info.Version : "") || (root.selectedItem ? root.selectedItem.version : "")],
                ["Repository", (root.infoReady ? root.info.Repository : "") || (root.selectedItem ? root.selectedItem.repo || "local" : "")],
                ["Packager / Developer", root.infoReady ? (root.info.Packager || root.info.Maintainer || "Not listed") : ""],
                ["Build date", root.infoReady ? (root.info["Build Date"] || "Not listed") : ""],
                ["Install date", root.infoReady ? (root.info["Install Date"] || "") : ""],
                ["URL", root.infoReady ? (root.info.URL || "Not listed") : ""],
                ["License", root.infoReady ? (root.info.Licenses || "Not listed") : ""],
                ["Download size", root.infoReady ? (root.info["Download Size"] || "") : ""],
                ["Installed size", root.infoReady ? (root.info["Installed Size"] || "") : ""],
                ["Groups", root.infoReady ? (root.info.Groups || "") : ""]
              ]
              delegate: Column {
                required property var modelData
                width: detailColumn.width
                spacing: 2
                visible: modelData[1] !== ""
                Text { text: modelData[0]; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; color: Colors.text_alt }
                Text { width: parent.width; text: modelData[1]; wrapMode: Text.Wrap; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: Colors.text }
              }
            }
            Text {
              width: parent.width
              visible: root.operationStatus !== "" || root.operationError !== ""
              text: root.operationError !== "" ? root.operationError : root.operationStatus
              wrapMode: Text.Wrap
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 11
              color: root.operationError !== "" ? Tokens.errorText : Colors.primary
            }
            Text {
              width: parent.width
              visible: root.uninstallMode
              text: "Removal clears Pacman-owned files and unused dependencies. User data and settings outside the package database need separate review."
              wrapMode: Text.Wrap
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 11
              color: Colors.text_alt
            }
          }
        }
      }
    }
  }
}
