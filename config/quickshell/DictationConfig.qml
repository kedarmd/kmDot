pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root
  property string provider: "handy"
  property string pendingProvider: ""
  property string errorText: ""
  property bool switching: false

  function script() {
    return Quickshell.env("HOME") + "/.config/kmdot/quickshell/scripts/dictation-provider.sh"
  }
  function setProvider(value, openLauncher) {
    const target = String(value)
    if ((target !== "handy" && target !== "hex") || target === root.provider || root.switching) return
    root.switching = true
    root.pendingProvider = target
    root.openLauncherAfterSwitch = !!openLauncher
    root.errorText = ""
    switchProc.exec(["bash", root.script(), "set", target])
  }
  property bool openLauncherAfterSwitch: false
  function load() { readProc.exec(["bash", root.script(), "get"]) }

  Component.onCompleted: root.load()
  Process {
    id: readProc
    stdout: StdioCollector {
      onStreamFinished: {
        const value = String(text).trim()
        if (value === "handy" || value === "hex") root.provider = value
      }
    }
  }
  Process {
    id: switchProc
    stderr: StdioCollector { onStreamFinished: root.errorText = String(text).trim() }
    onExited: function(code) {
      root.switching = false
      if (code === 0) {
        root.provider = root.pendingProvider
        if (root.openLauncherAfterSwitch) launcherProc.exec(["bash", root.script(), "launcher"])
      }
      else if (!root.errorText) root.errorText = "Could not switch dictation app"
      root.pendingProvider = ""
      root.openLauncherAfterSwitch = false
    }
  }
  Process { id: launcherProc }
}
