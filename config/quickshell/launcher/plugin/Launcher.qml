import QtQuick
import Quickshell
import Quickshell.Io
import "compat"
import "ui"

Item {
  id: root


  property bool opened: false
  property double openedAt: 0
  property var scope: null

  // Match the shell's launcher contract, including popup/lock coordination.
  function openLauncher(filter) { root.open(JSON.stringify({ filter: filter || "all" })) }
  function closeLauncher() { root.close() }
  function toggleLauncher(filter) {
    var mode = filter || "all"
    if (root.opened && launcher.atRoot && launcher.rootFilter === mode) root.close()
    else root.openLauncher(mode)
  }


  function open(payloadJson) {
    Color.refresh()
    var payload = ({})
    try { payload = JSON.parse(payloadJson || "{}") } catch (e) { payload = ({}) }
    var wasOpen = root.opened
    if (root.scope && root.scope.closeAllExcept) root.scope.closeAllExcept(root)
    if (root.scope) root.scope.activeLauncher = root
    root.opened = true
    root.openedAt = Date.now()
    launcher.prepare(payload)
    if (!wasOpen) backend.emit("window.visibilityChanged", { visible: true })
  }

  function close() {
    if (!root.opened) return
    root.opened = false
    if (root.scope && root.scope.activeLauncher === root) root.scope.activeLauncher = null
    backend.emit("window.visibilityChanged", { visible: false })
  }


  function show() {
    root.openLauncher("all")
  }

  function hide() {
    if (!root.opened) return
    root.close()
  }

  function toggle() {
    root.toggleLauncher("all")
  }

  function run(commandId) {
    var r = backend.callSync("rootSearch.performAction", { id: commandId, action: "open", query: "" })
    if (!r.ok) return r
    var outcome = r.data || {}
    if (outcome.filter) {
      root.openLauncher(outcome.filter)
    } else if (outcome.push) {
      root.show()
      launcher.popToRoot()
      launcher.push(outcome.push)
    } else if (outcome.close) {
      root.hide()
      if (outcome.hud) launcher.hud(outcome.hud)
    }
    return r
  }

  Backend {
    id: backend
  }

  Connections {
    target: backend
    function onNotification(method, data) {
      if (method !== "agent.launchReady") return
      root.hide()
      launcher.popToRoot()
      Util.execArgv(data.argv)
    }
  }

  LauncherWindow {
    id: launcher
    shown: root.opened
    backend: backend
    appLibrary: backend.appLibrary
    onDismissRequested: root.hide()
  }

  SocketServer {
    active: true
    path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/kmdot-kmdot.sock"
    handler: Socket {
      onConnectedChanged: if (connected) root.toggleLauncher()
    }
  }

  // The old app-picker socket is now a second entry point into this instance.
  SocketServer {
    active: true
    path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/kmdot-launcher.sock"
    handler: Socket {
      onConnectedChanged: if (connected) root.toggleLauncher("applications")
    }
  }

  IpcHandler {
    target: "kmdot-launcher"

    function toggle(): string {
      root.toggle()
      return root.opened ? "shown" : "hidden"
    }

    function show(): string {
      root.show()
      return "shown"
    }

    function search(query: string): string {
      root.open(JSON.stringify({ query: query, filter: "all" }))
      return "shown"
    }

    function showApplications(): string {
      root.openLauncher("applications")
      return "shown"
    }

    function filter(): string { return launcher.rootFilter }

    function hide(): string {
      root.hide()
      return "hidden"
    }

    function isOpen(): string {
      return root.opened ? "true" : "false"
    }

    function ping(): string {
      return "ok"
    }

    function run(commandId: string): string {
      return JSON.stringify(root.run(commandId))
    }

    function call(method: string, dataJson: string): string {
      var data = null
      if (dataJson && dataJson.length > 0) {
        try { data = JSON.parse(dataJson) } catch (e) {
          return JSON.stringify({ ok: false, error: "data is not JSON: " + e })
        }
      }
      return JSON.stringify(backend.callSync(method, data))
    }
  }
}
