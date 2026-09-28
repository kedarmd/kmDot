import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.Ui

// PROTOTYPE (wayfinder map "Omarchy plugin support", ticket "Themed pilot
// plugin proof in kmdot bar"): throwaway host that mounts one vendored
// Omarchy bar-widget inside the kmdot bar through the Tier-1 shim.
//
// Proves the hard seams: injected bar/moduleName/settings props, the
// bar.* facade (PluginBarApi fed from Colors), per-plugin Loader isolation
// with a fallback glyph row, anchor-under-module panel (native
// KeyboardPanel anchoring via injectPanel), full closeAllExcept/Esc/socket
// participation, and graceful Tier-2 degradation (missing omarchy-* CLIs
// log to stderr). NOT production code — see compat/PROTOTYPE.md.
Item {
  id: root
  implicitHeight: 30
  width: widgetLoader.status === Loader.Ready && widgetLoader.item
    ? widgetLoader.item.implicitWidth : fallback.implicitWidth
  height: 30

  // -- plugin identity (allowlist entry in plugins.json) --
  property string pluginId: "omarchy.clock"
  property string entryFile: "../plugins/omarchy.clock/BarWidget.qml"
  property string sockName: "kmdot-plugin-omarchy-clock"

  // -- kmdot wiring --
  property var scope: null // shellRoot: closeAllExcept lives here
  property var tooltip: null // shared kmdot Tooltip
  property var settings: ({}) // inline entry; live-patched, in-memory only

  readonly property bool pluginOpened: widgetLoader.item ? widgetLoader.item.opened === true : false
  readonly property bool loadFailed: widgetLoader.status === Loader.Error

  // Tier-1: settings write-back path (guarded updateEntryInline degrades
  // gracefully when the shim omits it; here it is emulated in memory).
  function applyEntryInline(entry) {
    var next = {}
    for (var key in entry) next[key] = entry[key]
    root.settings = next
    if (widgetLoader.item && "settings" in widgetLoader.item)
      widgetLoader.item.settings = next
  }

  function openPanel() {
    if (root.scope && root.scope.closeAllExcept) root.scope.closeAllExcept(root)
    if (widgetLoader.item) widgetLoader.item.open()
  }

  function closePanel() {
    if (widgetLoader.item) widgetLoader.item.close()
  }

  // closeAllExcept participant seam (popups loop calls close()).
  function close() { root.closePanel() }

  function summonPanel() {
    if (!root.pluginOpened) root.openPanel()
  }

  function togglePanel() {
    if (root.pluginOpened) root.closePanel()
    else root.openPanel()
  }

  function moduleWidgets(id) {
    if (!widgetLoader.item) return []
    if (!id || id === root.pluginId) return [widgetLoader.item]
    return []
  }

  PluginShellApi {
    id: shellApi
    pluginId: root.pluginId
    host: root
  }

  PluginBarApi {
    id: barFacade
    pluginId: root.pluginId
    moduleName: root.pluginId
    shell: shellApi

    foreground: Colors.text
    barForeground: Colors.text
    background: Colors.surface
    urgent: Colors.error
    fontFamily: "JetBrainsMono Nerd Font Propo"
    position: "top"
    vertical: false
    barSize: 30

    _showTooltip: function(target, text) {
      if (root.tooltip && text) root.tooltip.show(root, text)
    }
    _hideTooltip: function(target) {
      if (root.tooltip) root.tooltip.hide()
    }
    _registerClickTarget: function(target) {
      var targets = barFacade.clickTargets
      if (targets.indexOf(target) === -1) {
        targets.push(target)
        barFacade.clickTargets = targets
      }
    }
    _unregisterClickTarget: function(target) {
      var targets = barFacade.clickTargets
      var i = targets.indexOf(target)
      if (i !== -1) {
        targets.splice(i, 1)
        barFacade.clickTargets = targets
      }
    }
    // Single-popout model mapped onto the kmdot coordinator: taking over a
    // panel closes every other kmdot surface first.
    _requestPopout: function(owner) {
      barFacade.activePopout = owner
      if (root.scope && root.scope.closeAllExcept) root.scope.closeAllExcept(root)
    }
    _releasePopout: function(owner) {
      if (barFacade.activePopout === owner) barFacade.activePopout = null
    }
    _switchPanelFrom: function(owner, direction) {
      console.log("[plugin-shim:prototype] switchPanelFrom: single pilot plugin, no Tab target")
      return false
    }
    _targetBelongsToWindow: function(target, window) { return true }
    _moduleWidgets: function(id) { return root.moduleWidgets(id) }
    _run: function(command) { runProc.exec(["sh", "-c", command]) }
    _setCenterHoverRevealSuppressed: function(value) {}
  }

  Process {
    id: runProc
    onExited: function(exitCode) {
      if (exitCode !== 0)
        console.warn("[plugin-shim:prototype] run() exited " + exitCode + " (missing omarchy-* CLI degrades here)")
    }
  }

  Loader {
    id: widgetLoader
    anchors.fill: parent
    active: true
    source: Qt.resolvedUrl(root.entryFile)
    onLoaded: {
      // Host-injected props (the `in`-check contract: fill iff present).
      if ("bar" in item) item.bar = barFacade
      if ("moduleName" in item) item.moduleName = root.pluginId
      if ("settings" in item) item.settings = root.settings
    }
    onStatusChanged: {
      if (status === Loader.Error)
        console.error("[plugin-shim:prototype] Loader failed for " + root.pluginId + " (see quickshell stderr); showing fallback glyph")
    }
  }

  // Per-plugin Loader isolation: a broken plugin fails into this glyph row,
  // never into the whole bar process.
  Row {
    id: fallback
    anchors.centerIn: parent
    spacing: 6
    visible: root.loadFailed
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: "" // \uf017 fa-clock-o (4-hex escape: PUA-safe)
      font.family: "JetBrainsMono Nerd Font Propo"
      font.pixelSize: 15
      color: Colors.warning
    }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: "clock"
      font.family: "JetBrainsMono Nerd Font Propo"
      font.pixelSize: 12
      color: Colors.text_alt
    }
  }

  SocketServer {
    active: true
    path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/" + root.sockName + ".sock"
    handler: Socket {
      onConnectedChanged: if (connected) root.togglePanel()
    }
  }

  Component.onCompleted: console.log("[plugin-shim:prototype] host ready:", root.pluginId, "sock", root.sockName)
}
