import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs

// Generic single-pane picker. One instance per launcher; subclasses configure
// sockName/title/items and override filterAndSort()/refreshItems() and handle activated().
Item {
  id: root

  // ---- configuration ----
  property string sockName: "kmdot-launcher"
  property string title: "Search"
  property var items: []
  property string footerHint: "\u2191\u2193 navigate \u00b7 \u23ce select \u00b7 esc close"
  property bool countShown: true
  property string countNoun: "item"
  property bool deactivatable: true
  // If false, activate() keeps the launcher open and the subclass closes it itself
  // (needed when an item opens a prompt instead of closing — e.g. wifi passwords).
  property bool closeOnActivate: true
  // While the pool is being (re)built, show a spinner + loadingText instead of the
  // emptyText ("No matches"). Subclasses set `loading` true in refreshItems() and
  // false once the pool is ready (e.g. wifi scan in flight).
  property bool loading: false
  property string loadingText: "Loading\u2026"
  property string emptyText: "No matches"
  // Optional right-aligned footer pill (a state indicator + action, e.g. wifi on/off).
  // Rendered only when footerActionText is non-empty; Tab triggers footerActionClicked().
  property string footerActionText: ""
  property string footerActionGlyph: ""
  property bool footerActionActive: false
  // Prompt (password) mode: turns the search input into a masked field and swaps
  // the results list for a centered prompt. Used for e.g. wifi connection passwords.
  property bool promptMode: false
  property bool promptPassword: true
  property string promptTitle: "Enter value"
  property string promptError: ""
  property string promptHint: "\u23ce submit \u00b7 esc cancel"

  signal promptSubmitted(string text)

  // Shell scope that owns the launcher instances (set from shell.qml).
  // Used for the activeLauncher coordinator and cross-launcher navigation
  // (Scope does NOT parent its children, so root.parent is null).
  property var scope: null

  // ---- state ----
  property bool opened: false
  property string query: ""
  property var pool: root.items
  property var results: []
  property int selectedIndex: 0
  readonly property int resultCount: root.results.length

  readonly property string sockPath: {
    const rt = Quickshell.env("XDG_RUNTIME_DIR")
    return (rt ? rt : "/tmp") + "/" + root.sockName + ".sock"
  }

  signal activated(var item)
  signal footerActionClicked()
  signal itemAction(var action, var item)
  // Optional per-item modifier chords (e.g. Ctrl+R retry): each entry is
  // { key: int, ctrl: bool, hint: string }. A chord match on the search input
  // emits itemAction(action, selectedItem); hints are appended to the footer.
  // Bare keys must stay reserved for typing — chords only.
  property var itemActions: []

  readonly property string fullFooterHint: {
    const parts = [root.footerHint]
    for (const i in root.itemActions) parts.push(root.itemActions[i].hint || "")
    return parts.filter(p => p !== "").join(" \u00b7 ")
  }

  onQueryChanged: root.recompute()
  onPoolChanged: root.recompute()
  onOpenedChanged: {
    if (root.opened) focusTimer.start()
    root.onOpenedChange()
  }

  // ---- item accessors (menu items vs DesktopEntry apps) ----
  function itemLabel(item) { return item.label || item.name || "" }
  function itemSubtitle(item) { return item.subtitle || item.genericName || item.comment || "" }
  function itemGlyph(item) { return item.glyph || "" }
  function itemIcon(item) { return item.icon || "" }
  // Row-local extras (all default no-ops so existing launchers render unchanged):
  // statusGlyph = right-edge glyph (✓ selected, ▶/⏸ playback, spinner);
  // subtitleLive = subtitle override that may tick live (playback/retry state);
  // progress = 0..1 fill along the row's bottom edge;
  // body = optional third line under the subtitle (row grows taller only when set).
  function itemStatusGlyph(item) { return item.statusGlyph || "" }
  function itemSubtitleLive(item) { return root.itemSubtitle(item) }
  function itemProgress(item) { return item.progress || 0 }
  function itemBody(item) { return item.body || "" }

  function tryItemAction(event) {
    if (root.promptMode) return false
    const ctrl = (event.modifiers & Qt.ControlModifier) !== 0
    for (const i in root.itemActions) {
      const a = root.itemActions[i]
      if (a.key === event.key && !!a.ctrl === ctrl) {
        if (root.results.length === 0 || root.selectedIndex < 0
            || root.selectedIndex >= root.results.length) return false
        root.itemAction(a, root.results[root.selectedIndex].item)
        return true
      }
    }
    return false
  }

  // ---- matcher helpers ----
  function toStr(v) {
    if (v === undefined || v === null) return ""
    if (typeof v === "string") return v
    if (Array.isArray(v)) return v.join(" ")
    if (typeof v === "object" && typeof v.join === "function") return v.join(" ")
    return String(v)
  }

  function fieldScore(field, q) {
    const t = root.toStr(field).toLowerCase()
    const p = q.toLowerCase()
    if (!t || !p) return -1

    if (t === p) return 100000
    const sub = t.indexOf(p)
    if (sub >= 0) return 50000 - sub

    let score = 0
    let ti = 0
    let last = -2
    let consecutive = 0
    let first = -1
    for (let qi = 0; qi < p.length; qi++) {
      const ch = p[qi]
      let matched = false
      while (ti < t.length) {
        if (t[ti] === ch) {
          if (first < 0) first = ti
          if (last === ti - 1) {
            consecutive++
            score += 8
          } else {
            consecutive = 0
          }
          score += 2
          last = ti
          ti++
          matched = true
          break
        }
        ti++
      }
      if (!matched) return -1
    }
    if (first === 0) score += 50
    else if (first > 0) score += Math.max(0, 25 - first)
    score += Math.min(consecutive, 6) * 2
    return score
  }

  function matchScore(item, p) {
    let best = -1
    for (const f of [item.label, item.subtitle]) {
      if (f === undefined || f === null) continue
      const s = root.fieldScore(f, p)
      if (s >= 0) best = Math.max(best, s)
    }
    return best
  }

  function filterAndSort(items, q) {
    const out = []
    if (!q) {
      for (const it of items) out.push({ item: it, score: 0 })
      return out
    }
    const p = q.toLowerCase()
    for (const it of items) {
      const s = root.matchScore(it, p)
      if (s < 0) continue
      out.push({ item: it, score: s })
    }
    out.sort((a, b) => b.score - a.score)
    return out
  }

  // ---- lifecycle ----
  // Subclasses override to (re)build root.pool on each open (dynamic lists, e.g. wifi/themes).
  function refreshItems() {}

  // Called on every open/close (opened property changes) so subclasses can tie
  // work to visibility (e.g. bluetooth discovery). Subclasses must NOT re-declare
  // onOpenedChanged — that would shadow the base's focus-timer handler.
  function onOpenedChange() {}

  function recompute() {
    const q = root.query.trim()
    const filtered = root.filterAndSort(root.pool, q)
    root.results = filtered
    if (root.selectedIndex >= filtered.length) root.selectedIndex = 0
    if (filtered.length > 0) resultsList.positionViewAtIndex(root.selectedIndex, ListView.Center)
  }

  function openLauncher() {
    root.query = ""
    searchInput.text = ""
    root.selectedIndex = 0
    root.promptMode = false
    root.refreshItems()
    root.recompute()
    if (root.scope && root.scope.activeLauncher && root.scope.activeLauncher !== root) {
      root.scope.activeLauncher.closeLauncher()
    }
    if (root.scope && root.scope.batteryPopup) root.scope.batteryPopup.close()
    if (root.scope && root.scope.volumePopup) root.scope.volumePopup.close()
    if (root.scope && root.scope.brightnessPopup) root.scope.brightnessPopup.close()
    if (root.scope && root.scope.calendarPopup) root.scope.calendarPopup.close()
    if (root.scope && root.scope.serverModeDropdown) root.scope.serverModeDropdown.close()
    if (root.scope && root.scope.openCodeUsagePopup) root.scope.openCodeUsagePopup.close()
    if (root.scope && root.scope.handyPopup) root.scope.handyPopup.close()
    if (root.scope) root.scope.activeLauncher = root
    root.opened = true
  }

  function closeLauncher() {
    if (!root.opened) return
    root.opened = false
    if (root.scope && root.scope.activeLauncher === root) root.scope.activeLauncher = null
  }

  function toggleLauncher() {
    if (root.opened) root.closeLauncher()
    else root.openLauncher()
  }

  function startPrompt(title, error) {
    root.promptTitle = title
    root.promptError = error || ""
    root.query = ""
    searchInput.text = ""
    root.promptMode = true
    searchInput.forceActiveFocus()
  }

  function exitPrompt() {
    root.promptMode = false
    root.query = ""
    searchInput.text = ""
    root.recompute()
  }

  function step(delta) {
    if (root.results.length === 0) return
    root.selectedIndex = (root.selectedIndex + delta + root.results.length) % root.results.length
    resultsList.positionViewAtIndex(root.selectedIndex, ListView.Center)
  }

  // Clear the query both logically and visually (subclasses can't reach the
  // private search input).
  function resetQuery() {
    root.query = ""
    searchInput.text = ""
  }

  function activate() {
    if (!root.deactivatable) return
    if (root.selectedIndex < 0 || root.selectedIndex >= root.results.length) return
    const item = root.results[root.selectedIndex].item
    if (root.closeOnActivate) root.closeLauncher()
    root.activated(item)
  }

  function activateAt(i) {
    root.selectedIndex = i
    root.activate()
  }

  function runCommand(cmd) {
    cmdProc.exec(["sh", "-c", cmd])
  }

  Process {
    id: cmdProc
  }

  Timer {
    id: focusTimer
    interval: 60
    repeat: true
    onTriggered: {
      if (!root.opened) {
        focusTimer.stop()
        return
      }
      searchInput.forceActiveFocus()
      if (searchInput.activeFocus) focusTimer.stop()
    }
  }

  SocketServer {
    active: true
    path: root.sockPath
    handler: Socket {
      onConnectedChanged: {
        if (connected) root.toggleLauncher()
      }
    }
  }

  PanelWindow {
    id: launcherWin
    visible: root.opened
    screen: Quickshell.screens.values.length > 0 ? Quickshell.screens.values[0] : null
    color: Qt.rgba(0, 0, 0, 0.4)
    focusable: true

    // Blur whatever is behind the launcher (ext-background-effect-v1, Hyprland).
    BackgroundEffect.blurRegion: Region { item: launcherWin.contentItem }

    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    MouseArea {
      id: dimClick
      anchors.fill: parent
      onClicked: root.closeLauncher()
    }

    Rectangle {
      id: card
      width: 560
      height: 520
      anchors.centerIn: parent
      radius: 20
      color: Tokens.surfaceContainerHigh

      MouseArea {
        id: cardClick
        anchors.fill: parent
      }

      Rectangle {
        id: searchBar
        anchors {
          top: parent.top
          left: parent.left
          right: parent.right
          margins: 12
        }
        height: 48
        radius: 24
        color: Tokens.surfaceContainerHighest
        border.width: searchInput.activeFocus ? 1.5 : 0
        border.color: Tokens.primary

        Row {
          anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: 14
            rightMargin: 14
          }
          spacing: 10

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.promptMode ? "\uf023" : "\uf002"
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 15
            color: Colors.muted
          }

          TextInput {
            id: searchInput
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 40
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            color: Colors.text
            font.pixelSize: 15
            font.family: "JetBrainsMono Nerd Font Propo"
            selectByMouse: true
            cursorVisible: true
            clip: true
            echoMode: root.promptMode && root.promptPassword ? TextInput.Password : TextInput.Normal

            Text {
              anchors.fill: parent
              visible: parent.text === ""
              text: root.promptMode ? root.promptTitle : root.title
              color: Colors.muted
              font.pixelSize: 15
              font.family: parent.font.family
              verticalAlignment: Text.AlignVCenter
            }

            onTextEdited: {
              if (root.promptMode) return
              root.query = text
            }
            onAccepted: {
              if (root.promptMode) {
                const t = searchInput.text
                root.exitPrompt()
                root.promptSubmitted(t)
                return
              }
              root.activate()
            }

            Keys.onDownPressed: function(event) { root.step(1); event.accepted = true }
            Keys.onUpPressed: function(event) { root.step(-1); event.accepted = true }
            Keys.onPressed: function(event) {
              if (event.key === Qt.Key_PageUp) { root.step(10); event.accepted = true }
              else if (event.key === Qt.Key_PageDown) { root.step(-10); event.accepted = true }
              else if (root.tryItemAction(event)) event.accepted = true
            }
            Keys.onEscapePressed: function(event) {
              if (root.promptMode) {
                root.exitPrompt()
                event.accepted = true
                return
              }
              root.closeLauncher()
              event.accepted = true
            }
            Keys.onTabPressed: function(event) {
              if (root.footerActionText !== "") root.footerActionClicked()
              event.accepted = true
            }
            Keys.onBacktabPressed: function(event) { event.accepted = true }
          }
        }
      }

      ListView {
        id: resultsList
        anchors {
          top: searchBar.bottom
          left: parent.left
          right: parent.right
          bottom: footer.top
          leftMargin: 12
          rightMargin: 12
          topMargin: 8
          bottomMargin: 8
        }
        visible: !root.promptMode
        clip: true
        model: root.results
        focus: false
        interactive: true
        flickDeceleration: 2500

        delegate: Rectangle {
          required property var modelData
          required property int index
          width: resultsList.width
          height: bodyText.visible ? bodyText.height + 56 : 52
          radius: 14
          color: root.selectedIndex === index ? Tokens.primaryContainer : "transparent"

          Row {
            anchors {
              left: parent.left
              right: parent.right
              verticalCenter: parent.verticalCenter
              leftMargin: 10
              rightMargin: 10
            }
            spacing: 12

            Rectangle {
              width: 32
              height: 32
              radius: 16
              anchors.verticalCenter: parent.verticalCenter
              color: root.selectedIndex === index ? Tokens.primaryContainer : Tokens.surfaceContainerHighest
              visible: root.itemGlyph(modelData.item) !== "" || root.itemIcon(modelData.item) !== ""

              Text {
                anchors.centerIn: parent
                visible: root.itemGlyph(modelData.item) !== ""
                text: root.itemGlyph(modelData.item)
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 16
                color: root.selectedIndex === index ? Tokens.on_primary_container : Colors.text_alt
              }

              Image {
                anchors.centerIn: parent
                width: 28
                height: 28
                visible: root.itemGlyph(modelData.item) === "" && root.itemIcon(modelData.item) !== ""
                source: (function () {
                  const ic = root.itemIcon(modelData.item)
                  if (ic === "") return ""
                  if (ic.startsWith("/") || ic.startsWith("file://") || ic.startsWith("image://")) return ic
                  return Quickshell.iconPath(ic)
                })()
              }
            }

            Column {
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width - 40 - (statusGlyphText.visible ? statusGlyphText.implicitWidth + 14 : 0)

              Text {
                width: parent.width
                text: root.itemLabel(modelData.item)
                elide: Text.ElideRight
                font.pixelSize: 14
                font.bold: root.selectedIndex === index
                font.family: "JetBrainsMono Nerd Font Propo"
                color: root.selectedIndex === index ? Tokens.on_primary_container : Colors.text_alt
              }

              Text {
                width: parent.width
                text: root.itemSubtitleLive(modelData.item)
                elide: Text.ElideRight
                font.pixelSize: 12
                font.family: "JetBrainsMono Nerd Font Propo"
                color: root.selectedIndex === index ? Tokens.alpha(Tokens.on_primary_container, 0.75) : Colors.muted
                visible: text !== ""
              }

              Text {
                id: bodyText
                width: parent.width
                visible: root.itemBody(modelData.item) !== ""
                text: root.itemBody(modelData.item)
                wrapMode: Text.Wrap
                font.pixelSize: 11
                font.family: "JetBrainsMono Nerd Font Propo"
                color: root.selectedIndex === index ? Tokens.alpha(Tokens.on_primary_container, 0.6) : Colors.text_alt
              }
            }
          }

          Text {
            id: statusGlyphText
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            visible: root.itemStatusGlyph(modelData.item) !== ""
            text: root.itemStatusGlyph(modelData.item)
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 14
            color: root.selectedIndex === index ? Tokens.on_primary_container : Colors.primary
          }

          Rectangle {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 6
            anchors.left: parent.left
            anchors.leftMargin: 12
            width: (parent.width - 24) * Math.min(1, Math.max(0, root.itemProgress(modelData.item)))
            height: 3
            radius: 1
            color: Colors.primary
            visible: width > 0
          }

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: root.selectedIndex = index
            onClicked: root.activateAt(index)
          }
        }
      }

      Column {
        anchors.centerIn: parent
        visible: !root.promptMode && root.results.length === 0
        spacing: 12

        Text {
          id: loadingSpinner
          anchors.horizontalCenter: parent.horizontalCenter
          visible: root.loading
          text: "\uf110"
          font.pixelSize: 24
          font.family: "JetBrainsMono Nerd Font Propo"
          color: Colors.primary

          RotationAnimation on rotation {
            from: 0
            to: 360
            duration: 900
            loops: Animation.Infinite
            running: root.loading
          }
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: root.loading ? root.loadingText : root.emptyText
          font.pixelSize: 14
          font.family: "JetBrainsMono Nerd Font Propo"
          color: Colors.muted
        }
      }

      Column {
        anchors {
          top: searchBar.bottom
          left: parent.left
          right: parent.right
          bottom: footer.top
          topMargin: 16
          bottomMargin: 8
        }
        visible: root.promptMode
        spacing: 10

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: root.promptTitle
          color: Colors.text
          font.pixelSize: 17
          font.family: "JetBrainsMono Nerd Font Propo"
          horizontalAlignment: Text.AlignHCenter
          width: parent.width
          wrapMode: Text.Wrap
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: root.promptError
          visible: root.promptError !== ""
          color: Colors.error
          font.pixelSize: 13
          font.family: "JetBrainsMono Nerd Font Propo"
          horizontalAlignment: Text.AlignHCenter
          width: parent.width
          wrapMode: Text.Wrap
        }
      }

      Rectangle {
        id: footer
        anchors {
          left: parent.left
          right: parent.right
          bottom: parent.bottom
          leftMargin: 1
          rightMargin: 1
          bottomMargin: 1
        }
        height: 42
        radius: 20
        color: Colors.base

        Rectangle {
          anchors {
            top: parent.top
            left: parent.left
            right: parent.right
          }
          height: 20
          color: Colors.base
        }

        Rectangle {
          anchors {
            top: parent.top
            left: parent.left
            right: parent.right
          }
          height: 1
          color: Tokens.divider
        }

        Row {
          anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: 12
            rightMargin: 12
          }
          spacing: 8

          Text {
            id: footerHintText
            anchors.verticalCenter: parent.verticalCenter
            text: root.promptMode ? root.promptHint : root.fullFooterHint
            font.pixelSize: 12
            font.family: "JetBrainsMono Nerd Font Propo"
            color: Colors.muted
            // Keep the hint within its own space so it never runs underneath the
            // right-aligned footer pill (e.g. bluetooth/wifi on-off button).
            elide: Text.ElideRight
            width: root.footerActionText !== ""
              ? parent.width - footerPill.width - 12
              : footerHintText.implicitWidth
          }

          Item {
            id: footerSpacer
            width: parent.width - footerHintText.width - footerCountText.width - 16
            height: 1
          }

          Text {
            id: footerCountText
            anchors.verticalCenter: parent.verticalCenter
            text: root.countShown
              ? root.resultCount + " " + root.countNoun + (root.resultCount === 1 ? "" : "s")
              : ""
            font.pixelSize: 12
            font.family: "JetBrainsMono Nerd Font Propo"
            color: Colors.muted
            horizontalAlignment: Text.AlignRight
            visible: root.countShown
            width: root.countShown ? footerCountText.implicitWidth : 0
          }
        }

        Rectangle {
          id: footerPill
          anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
            rightMargin: 12
          }
          visible: root.footerActionText !== ""
          height: 28
          width: footerActionRow.implicitWidth + 20
          radius: 14
          color: root.footerActionActive ? Tokens.primaryContainer : "transparent"
          border.width: 1
          border.color: root.footerActionActive ? "transparent" : Tokens.outlineVariant

          Row {
            id: footerActionRow
            anchors.centerIn: parent
            spacing: 6

            Text {
              anchors.verticalCenter: parent.verticalCenter
              visible: root.footerActionGlyph !== ""
              text: root.footerActionGlyph
              font.pixelSize: 12
              font.family: "JetBrainsMono Nerd Font Propo"
              color: root.footerActionActive ? Tokens.on_primary_container : Colors.muted
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: root.footerActionText
              font.pixelSize: 12
              font.family: "JetBrainsMono Nerd Font Propo"
              font.weight: root.footerActionActive ? Font.Bold : Font.Normal
              color: root.footerActionActive ? Tokens.on_primary_container : Colors.muted
            }
          }

          StateLayer {
            anchors.fill: parent
            radius: parent.radius
            hovered: pillHover.containsMouse
            pressed: pillHover.pressed
          }

          MouseArea {
            id: pillHover
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.footerActionClicked()
          }
        }
      }
    }
  }
}
