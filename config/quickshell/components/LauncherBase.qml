import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import "./popuppos.js" as Pos

// Generic single-pane picker. One instance per launcher; subclasses configure
// sockName/title/items and override filterAndSort()/refreshItems() and handle activated().
Item {
  id: root

  // ---- configuration ----
  property string sockName: "kmdot-launcher"
  property string title: "Search"
  property string searchPlaceholder: ""
  // Compact destination title. The search placeholder remains `title`.
  property string headerTitle: ""
  property string resultsLabel: ""
  property string listStatusText: ""
  property string listStatusActionText: ""
  property string listStatusActionGlyph: ""
  property real listStatusActionWidth: 0
  property Component listToolbar: null
  property real cardHeight: 608
  property real listTopMargin: 16
  property bool themePreview: false
  // Optional palette for a live theme preview; defaults to the active shell palette.
  property var themePreviewPalette: null
  // Title row shown in the search bar's slot when searchEnabled is false
  // (e.g. "Handy History"). Empty = no header row.
  property string headerText: ""
  property string headerGlyph: ""
  property var items: []
  property string footerHint: "\u2191\u2193 navigate \u00b7 \u23ce select"
  property string closeHint: "esc  Close"
  property bool countShown: false
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
  property string emptyIconName: "search"
  // Optional right-aligned footer pill (a state indicator + action, e.g. wifi on/off).
  // Rendered only when footerActionText is non-empty; Tab triggers footerActionClicked().
  property string footerActionText: ""
  property string footerActionGlyph: ""
  property bool footerActionActive: false
  property bool footerActionVisible: true
  // Prompt (password) mode: turns the search input into a masked field and swaps
  // the results list for a centered prompt. Used for e.g. wifi connection passwords.
  property bool promptMode: false
  property bool promptPassword: true
  property string promptTitle: "Enter value"
  property string promptError: ""
  property string promptHint: "\u23ce submit \u00b7 esc cancel"

  signal promptSubmitted(string text)
  signal detailBackRequested()
  signal detailAcceptRequested()

  // Shell scope that owns the launcher instances (set from shell.qml).
  // Used for the activeLauncher coordinator and cross-launcher navigation
  // (Scope does NOT parent its children, so root.parent is null).
  property var scope: null

  // ---- state ----
  property bool opened: false
  property bool presentationVisible: false
  property string query: ""
  property var pool: root.items
  property var results: []
  property int selectedIndex: 0
  readonly property int resultCount: root.results.length
  readonly property var selectedItem: root.results.length > 0
    && root.selectedIndex >= 0 && root.selectedIndex < root.results.length
    ? root.results[root.selectedIndex].item : null

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
  // When false the search bar collapses and keyboard focus moves to an invisible
  // nav Item (up/down/page/enter/esc/tab + chords). Only that surface honors
  // bareKeyActions — the search input never consumes bare keys.
  property bool searchEnabled: true
  property bool detailMode: false
  property Component detailContent: null
  // Bare (modifier-less) key actions for the no-search surface, e.g. Delete on
  // a list view. Entries: { key, hint }; hints are appended to the footer.
  property var bareKeyActions: []

  readonly property string fullFooterHint: {
    const parts = [root.footerHint]
    for (const i in root.itemActions) parts.push(root.itemActions[i].hint || "")
    for (const i in root.bareKeyActions) parts.push(root.bareKeyActions[i].hint || "")
    return parts.filter(p => p !== "").join(" \u00b7 ")
  }

  onQueryChanged: root.recompute()
  onPoolChanged: root.recompute()
  onOpenedChanged: {
    if (root.opened) {
      closePresentationTimer.stop()
      root.presentationVisible = true
      focusTimer.start()
    } else {
      closePresentationTimer.restart()
    }
    root.onOpenedChange()
  }
  // Mode flips (e.g. Models ↔ History) swap the focus target.
  onSearchEnabledChanged: if (root.opened) focusTimer.restart()

  // ---- item accessors (menu items vs DesktopEntry apps) ----
  function itemLabel(item) { return item.label || item.name || "" }
  function itemSubtitle(item) { return item.subtitle || item.genericName || item.comment || "" }
  function itemGlyph(item) { return item.glyph || "" }
  function itemIcon(item) { return item.icon || "" }
  // Row title seam: defaults to itemLabel so subclasses can compose breadcrumbs
  // (e.g. "Section → Item") for nested search results without touching scoring.
  function itemTitle(item) { return root.itemLabel(item) }
  // Row-local extras (all default no-ops so existing launchers render unchanged):
  // statusGlyph = right-edge glyph (✓ selected, ▶/⏸ playback, spinner);
  // subtitleLive = subtitle override that may tick live (playback/retry state);
  // progress = 0..1 fill along the row's bottom edge;
  // body = optional third line under the subtitle (row grows taller only when set).
  function itemStatusGlyph(item) { return item.statusGlyph || "" }
  function itemMeta(item) { return item.meta || "" }
  function itemSwatches(item) { return item.swatches || [] }
  function itemSubtitleLive(item) { return root.itemSubtitle(item) }
  function itemProgress(item) { return item.progress || 0 }
  function itemBody(item) { return item.body || "" }

  function themePreviewColor(role) {
    const palette = root.themePreviewPalette
    return palette && palette[role] ? palette[role] : Colors[role]
  }

  function themePreviewCardColor() {
    const surface = String(root.themePreviewColor("surface"))
    return surface.toLowerCase() === String(root.themePreviewColor("base")).toLowerCase()
      ? root.themePreviewColor("surface_high") : surface
  }

  function themePreviewBarColor() {
    const surface = String(root.themePreviewColor("surface"))
    return surface.toLowerCase() === String(root.themePreviewColor("base")).toLowerCase()
      ? root.themePreviewColor("surface_alt") : surface
  }

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

  // Keyboard handler for the no-search nav surface: bareKeyActions match
  // modifier-less presses; itemActions chords still work here.
  function tryNavItemAction(event) {
    const ctrl = (event.modifiers & Qt.ControlModifier) !== 0
    const selected = root.results.length > 0 && root.selectedIndex >= 0
      && root.selectedIndex < root.results.length
      ? root.results[root.selectedIndex].item : null
    for (const i in root.bareKeyActions) {
      const a = root.bareKeyActions[i]
      if (!ctrl && a.key === event.key) {
        if (!selected) return false
        root.itemAction(a, selected)
        return true
      }
    }
    for (const i in root.itemActions) {
      const a = root.itemActions[i]
      if (a.key === event.key && !!a.ctrl === ctrl) {
        if (!selected) return false
        root.itemAction(a, selected)
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
    if (filtered.length > 0) resultsList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
  }

  function openLauncher() {
    root.query = ""
    searchInput.text = ""
    root.selectedIndex = 0
    root.promptMode = false
    root.refreshItems()
    root.recompute()
    // Overlay coordinator owns cross-kind closing (shell.qml closeAllExcept):
    // one call replaces the hand-rolled sibling list (which omitted the
    // notification center and the radio dropdowns). activeLauncher bookkeeping
    // stays here; closeAllExcept drives the actual closing.
    if (root.scope && root.scope.closeAllExcept) root.scope.closeAllExcept(root)
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
    resultsList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
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
    id: closePresentationTimer
    interval: Tokens.motionStandard
    onTriggered: root.presentationVisible = false
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
      const target = root.searchEnabled ? searchInput : navKeys
      target.forceActiveFocus()
      if (target.activeFocus) focusTimer.stop()
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
    visible: root.presentationVisible
    // NOTE: Pos.primaryScreen (indexed), not .values (see PopupBase screen binding).
    screen: Pos.primaryScreen(Quickshell.screens)
    color: Qt.rgba(0, 0, 0, 0)
    focusable: true


    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: Qt.rgba(0, 0, 0, root.opened ? 0.4 : 0)
      Behavior on color {
        ColorAnimation { duration: Tokens.motionStandard; easing.type: Easing.OutCubic }
      }
    }

    MouseArea {
      id: dimClick
      anchors.fill: parent
      onClicked: root.closeLauncher()
    }

    Rectangle {
      id: card
      width: Math.min(640, parent.width - 32)
      height: Math.min(root.cardHeight, parent.height - 32)
      anchors.centerIn: parent
      radius: 32
      color: Colors.surface
      border.width: 1
      border.color: Colors.border
      opacity: root.opened ? 1 : 0
      scale: root.opened ? 1 : 0.96

      Behavior on opacity {
        NumberAnimation { duration: Tokens.motionStandard; easing.type: Easing.OutCubic }
      }
      Behavior on scale {
        NumberAnimation { duration: Tokens.motionEmphasized; easing.type: Easing.OutBack }
      }

      MouseArea {
        id: cardClick
        anchors.fill: parent
      }

      Text {
        id: heading
        anchors { top: parent.top; left: parent.left; topMargin: 24; leftMargin: 24 }
        text: root.headerTitle
        visible: text !== ""
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 20
        font.weight: Font.DemiBold
        color: Colors.text
      }

      R1Icon {
        width: 24
        height: 24
        anchors { right: parent.right; top: parent.top; rightMargin: 32; topMargin: 32 }
        glyph: "\uf00d"
        font.family: "JetBrainsMono Nerd Font Propo"
        font.pixelSize: 16
        color: Colors.text_alt
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        MouseArea {
          anchors.fill: parent
          anchors.margins: -8
          cursorShape: Qt.PointingHandCursor
          onClicked: root.closeLauncher()
        }
      }

      // Invisible key-catcher for searchless views (e.g. Handy History): owns
      // keyboard focus so bare keys reach the list instead of a text input.
      Item {
        id: navKeys
        anchors.fill: parent
        visible: !root.searchEnabled

        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Down) { root.step(1); event.accepted = true }
          else if (event.key === Qt.Key_Up) { root.step(-1); event.accepted = true }
          else if (event.key === Qt.Key_PageUp) { root.step(10); event.accepted = true }
          else if (event.key === Qt.Key_PageDown) { root.step(-10); event.accepted = true }
          else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (root.detailMode) root.detailAcceptRequested()
            else root.activate()
            event.accepted = true
          }
          else if (event.key === Qt.Key_Escape) {
            if (root.detailMode) root.detailBackRequested()
            else root.closeLauncher()
            event.accepted = true
          }
          else if (event.key === Qt.Key_Tab) {
            if (root.footerActionText !== "" || root.listStatusActionText !== "") root.footerActionClicked()
            event.accepted = true
          }
          else if (root.tryNavItemAction(event)) event.accepted = true
        }
      }

      // Title row for searchless views: occupies the search bar's exact slot.
      Item {
        id: listHeader
        visible: !root.searchEnabled && !root.detailMode && root.headerText !== ""
        anchors {
          top: parent.top
          left: parent.left
          right: parent.right
          leftMargin: 24
          rightMargin: 24
          topMargin: 72
        }
        height: 56

        Row {
          anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: 16
            rightMargin: 16
          }
          spacing: 16

          R1Icon {
            id: headerGlyphText
            anchors.verticalCenter: parent.verticalCenter
            visible: root.headerGlyph !== ""
            glyph: root.headerGlyph
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 16
            color: Colors.primary
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - (headerGlyphText.visible ? headerGlyphText.width + parent.spacing : 0)
            text: root.headerText
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 16
            font.weight: Font.DemiBold
            color: Colors.text
            elide: Text.ElideRight
          }
        }
      }

      Rectangle {
        id: searchBar
        visible: root.searchEnabled && !root.detailMode
        anchors {
          top: parent.top
          left: parent.left
          right: parent.right
          leftMargin: root.searchEnabled ? 24 : 0
          rightMargin: root.searchEnabled ? 24 : 0
          topMargin: root.searchEnabled ? 64 : 0
        }
        height: root.searchEnabled ? 56 : 0
        radius: 16
        color: root.themePreviewColor("surface_alt")
        border.width: searchInput.activeFocus ? 1.5 : 0
        border.color: Tokens.primary

        Row {
          anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: 16
            rightMargin: 16
          }
          spacing: 16

          R1Icon {
            anchors.verticalCenter: parent.verticalCenter
            glyph: root.promptMode ? "\uf023" : "\uf002"
            width: 24
            horizontalAlignment: Text.AlignHCenter
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 16
            color: Tokens.mutedText
          }

          TextInput {
            id: searchInput
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 104
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            color: Colors.text
            font.pixelSize: 16
            font.family: "JetBrainsMono Nerd Font"
            selectByMouse: true
            cursorVisible: true
            clip: true
            echoMode: root.promptMode && root.promptPassword ? TextInput.Password : TextInput.Normal

            Text {
              anchors.fill: parent
              visible: parent.text === ""
              text: root.promptMode ? root.promptTitle
                : (root.searchPlaceholder !== "" ? root.searchPlaceholder : root.title)
              color: Tokens.mutedText
              font.pixelSize: 16
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
              if (root.footerActionText !== "" || root.listStatusActionText !== "") root.footerActionClicked()
              event.accepted = true
            }
            Keys.onBacktabPressed: function(event) { event.accepted = true }
          }

        }

        Text {
          anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 16 }
          width: 36
          text: "Esc"
          horizontalAlignment: Text.AlignRight
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 12
          font.weight: Font.Medium
          color: Colors.text_alt
        }
      }

      Loader {
        id: toolbarLoader
        anchors {
          top: searchBar.visible ? searchBar.bottom : parent.top
          left: parent.left
          right: parent.right
          leftMargin: 24
          rightMargin: 24
          topMargin: searchBar.visible ? 20 : 72
        }
        height: root.listToolbar ? 40 : 0
        visible: root.listToolbar !== null
        sourceComponent: visible ? root.listToolbar : null
      }

      Rectangle {
        id: themePreviewCard
        visible: root.themePreview
        anchors { top: parent.top; left: parent.left; right: parent.right; leftMargin: 24; rightMargin: 24; topMargin: 64 }
        height: 208
        radius: 24
        color: root.themePreviewColor("base")

        Rectangle {
          anchors { top: parent.top; left: parent.left; right: parent.right; margins: 16 }
          height: 24
          radius: 12
          color: root.themePreviewBarColor()
        }

        Rectangle {
          anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 60 }
          width: 272
          height: 124
          radius: 16
          color: root.themePreviewCardColor()

          Text {
            anchors { left: parent.left; top: parent.top; leftMargin: 16; right: parent.right; rightMargin: 16; topMargin: 14 }
            text: root.selectedItem ? root.itemLabel(root.selectedItem) : "TokyoNight · Night"
            elide: Text.ElideRight
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 20
            font.weight: Font.DemiBold
            color: root.themePreviewColor("text")
          }
          Rectangle {
            x: 16
            y: 56
            width: 240
            height: 36
            radius: 12
            color: root.themePreviewColor("primary_container")
          }
          Text {
            anchors { left: parent.left; top: parent.top; leftMargin: 28; topMargin: 64 }
            text: "A little calm. A little color."
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            color: root.themePreviewColor("on_primary_container")
          }
        }
        Rectangle { x: 24; y: 166; width: 24; height: 24; radius: 12; color: root.themePreviewColor("primary") }
        Rectangle { x: 56; y: 166; width: 24; height: 24; radius: 12; color: root.themePreviewColor("primary_alt") }
        Rectangle { x: 88; y: 166; width: 24; height: 24; radius: 12; color: root.themePreviewColor("accent") }
        Rectangle { x: 120; y: 166; width: 24; height: 24; radius: 12; color: root.themePreviewColor("success") }
        Rectangle { x: 152; y: 166; width: 24; height: 24; radius: 12; color: root.themePreviewColor("warning") }
        Rectangle { x: 184; y: 166; width: 24; height: 24; radius: 12; color: root.themePreviewColor("error") }
      }

      Text {
        id: resultsHeading
        visible: root.resultsLabel !== "" && !root.themePreview
        anchors { top: searchBar.bottom; left: parent.left; topMargin: 16; leftMargin: 36 }
        text: root.resultsLabel
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 12
        font.weight: Font.DemiBold
        color: Colors.text_alt
      }

      ListView {
        id: resultsList
        anchors {
          top: toolbarLoader.visible ? toolbarLoader.bottom
            : themePreviewCard.visible ? themePreviewCard.bottom
            : (resultsHeading.visible ? resultsHeading.bottom
              : (listHeader.visible ? listHeader.bottom : searchBar.bottom))
          left: parent.left
          right: parent.right
          bottom: footer.top
          leftMargin: 24
          rightMargin: 24
          topMargin: toolbarLoader.visible ? 24 : root.themePreview ? 24
            : (root.searchEnabled
              ? (resultsHeading.visible ? 6 : root.listTopMargin)
              : (listHeader.visible ? 16 : 72))
          bottomMargin: root.listStatusText !== "" || root.listStatusActionText !== "" ? 88 : 8
        }
        visible: !root.promptMode && !root.detailMode
        clip: true
        model: root.results
        focus: false
        interactive: true
        flickDeceleration: 2500

        delegate: Rectangle {
          required property var modelData
          required property int index
          width: resultsList.width
          height: bodyText.visible ? bodyText.height + 64 : 64
          radius: 16
          color: root.selectedIndex === index ? Colors.primary_container : "transparent"

          Behavior on height {
            NumberAnimation { duration: Tokens.motionStandard; easing.type: Easing.OutCubic }
          }

          Behavior on color {
            ColorAnimation { duration: Tokens.motionFast; easing.type: Easing.OutCubic }
          }

          Row {
            anchors {
              left: parent.left
              right: parent.right
              verticalCenter: parent.verticalCenter
              leftMargin: 12
              rightMargin: 12
            }
            spacing: 12

            Rectangle {
              width: 40
              height: 40
              radius: 12
              anchors.verticalCenter: parent.verticalCenter
                color: Colors.surface_alt
              visible: root.itemGlyph(modelData.item) !== "" || root.itemIcon(modelData.item) !== ""

              R1Icon {
                anchors.centerIn: parent
                visible: root.itemGlyph(modelData.item) !== ""
                glyph: root.itemGlyph(modelData.item)
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 24
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
              width: parent.width - 52
                - (statusGlyphText.visible ? statusGlyphText.implicitWidth + 14 : 0)
                - (itemMetaText.visible ? itemMetaText.implicitWidth + 24 : 0)
                - (itemSwatchesRow.visible ? itemSwatchesRow.implicitWidth + 24 : 0)

              Text {
                width: parent.width
                text: root.itemTitle(modelData.item)
                elide: Text.ElideRight
                font.pixelSize: 16
                font.weight: Font.DemiBold
                font.family: "JetBrainsMono Nerd Font"
                color: Colors.text
              }

              Text {
                width: parent.width
                text: root.itemSubtitleLive(modelData.item)
                elide: Text.ElideRight
                font.pixelSize: 12
                font.family: "JetBrainsMono Nerd Font"
                color: root.selectedIndex === index ? Tokens.on_primary_container : Colors.text_alt
                visible: text !== ""
              }

              Text {
                id: bodyText
                width: parent.width
                visible: root.itemBody(modelData.item) !== ""
                text: root.itemBody(modelData.item)
                wrapMode: Text.Wrap
                font.pixelSize: 12
                font.family: "JetBrainsMono Nerd Font"
                color: root.selectedIndex === index ? Tokens.on_primary_container : Colors.text_alt
              }
            }
          }

          R1Icon {
            id: statusGlyphText
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            visible: root.itemStatusGlyph(modelData.item) !== ""
              || (root.deactivatable && root.selectedIndex === index && root.itemMeta(modelData.item) === "")
            glyph: root.itemStatusGlyph(modelData.item) !== ""
              ? root.itemStatusGlyph(modelData.item) : "\u21b5"
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 14
            color: root.selectedIndex === index ? Tokens.on_primary_container : Colors.primary
          }

          Text {
            id: itemMetaText
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            visible: root.itemMeta(modelData.item) !== ""
            text: root.itemMeta(modelData.item)
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            font.weight: Font.Medium
            color: root.selectedIndex === index ? Tokens.on_primary_container : Colors.text_alt
          }

          Row {
            id: itemSwatchesRow
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            visible: root.itemSwatches(modelData.item).length > 0 && !itemMetaText.visible

            Repeater {
              model: root.itemSwatches(modelData.item)
              delegate: Rectangle {
                required property var modelData
                width: 8
                height: 8
                radius: 4
                color: modelData
              }
            }
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

      Loader {
        anchors {
          top: parent.top
          left: parent.left
          right: parent.right
          bottom: footer.top
          leftMargin: 24
          rightMargin: 24
          topMargin: 64
          bottomMargin: 16
        }
        visible: root.detailMode
        sourceComponent: root.detailMode ? root.detailContent : null
      }

      Text {
        anchors {
          left: parent.left
          bottom: footer.top
          leftMargin: 36
          bottomMargin: 64
        }
        visible: !root.detailMode && !root.promptMode && root.listStatusText !== ""
        text: root.listStatusText
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 12
        color: Colors.text_alt
      }

      Rectangle {
        width: root.listStatusActionWidth > 0 ? root.listStatusActionWidth : statusActionRow.implicitWidth + 32
        height: 40
        radius: 20
        anchors {
          right: parent.right
          bottom: footer.top
          rightMargin: 24
          bottomMargin: 44
        }
        visible: !root.detailMode && !root.promptMode && root.listStatusActionText !== ""
        color: Tokens.primaryContainer

        Row {
          id: statusActionRow
          anchors.centerIn: parent
          spacing: 8

          R1Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.listStatusActionGlyph !== ""
            glyph: root.listStatusActionGlyph
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 12
            color: Tokens.on_primary_container
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.listStatusActionText
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
            font.weight: Font.DemiBold
            color: Tokens.on_primary_container
          }
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.footerActionClicked()
        }
      }

      Column {
        anchors.centerIn: parent
        visible: !root.promptMode && root.results.length === 0
        spacing: 12

        R1Icon {
          anchors.horizontalCenter: parent.horizontalCenter
          visible: !root.loading
          iconName: root.emptyIconName
          font.pixelSize: 24
          color: Tokens.errorText
        }

        R1Icon {
          id: loadingSpinner
          anchors.horizontalCenter: parent.horizontalCenter
          visible: root.loading
          glyph: "\uf110"
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
          font.family: "JetBrainsMono Nerd Font"
          color: Tokens.mutedText
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
          font.pixelSize: 16
          font.family: "JetBrainsMono Nerd Font"
          horizontalAlignment: Text.AlignHCenter
          width: parent.width
          wrapMode: Text.Wrap
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: root.promptError
          visible: root.promptError !== ""
          color: Tokens.errorText
          font.pixelSize: 14
          font.family: "JetBrainsMono Nerd Font"
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
        height: 56
        radius: 32
        color: Colors.base

        Rectangle {
          anchors {
            top: parent.top
            left: parent.left
            right: parent.right
          }
          height: 28
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
            leftMargin: 24
            rightMargin: 24
          }
          spacing: 8

          Text {
            id: footerHintText
            anchors.verticalCenter: parent.verticalCenter
            text: root.promptMode ? root.promptHint : root.fullFooterHint
            font.pixelSize: 12
            font.family: "JetBrainsMono Nerd Font"
            color: Tokens.mutedText
            // Keep the hint within its own space so it never runs underneath the
            // right-aligned footer pill (e.g. bluetooth/wifi on-off button).
            elide: Text.ElideRight
            width: root.footerActionText !== "" && root.footerActionVisible
              ? Math.max(0, parent.width - footerPill.width - 12)
              : Math.max(0, parent.width - 136)
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
              : root.closeHint
            font.pixelSize: 12
            font.family: "JetBrainsMono Nerd Font"
            color: Tokens.mutedText
            horizontalAlignment: Text.AlignRight
            visible: root.countShown || (root.closeHint !== "" && (!root.footerActionVisible || root.footerActionText === ""))
            width: visible ? (root.countShown ? footerCountText.implicitWidth : 116) : 0
          }
        }

        Rectangle {
          id: footerPill
          anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
            rightMargin: 24
          }
          visible: root.footerActionText !== "" && root.footerActionVisible
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
              font.family: "JetBrainsMono Nerd Font"
              color: root.footerActionActive ? Tokens.on_primary_container : Tokens.mutedText
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: root.footerActionText
              font.pixelSize: 12
              font.family: "JetBrainsMono Nerd Font"
              font.weight: root.footerActionActive ? Font.Bold : Font.Normal
              color: root.footerActionActive ? Tokens.on_primary_container : Tokens.mutedText
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
