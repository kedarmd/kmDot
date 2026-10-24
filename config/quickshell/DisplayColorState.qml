pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root
  property var values: ({})
  property bool available: false
  property string reason: "Checking color controls…"
  property string error: ""
  property var pending: null
  property var inFlight: null
  readonly property string script: Quickshell.shellDir + "/scripts/display-color.sh"
  readonly property bool supported: available && !!DisplayState.selectedDisplay
    && !DisplayState.selectedDisplay.disabled
    && !/^hdr/.test(DisplayState.selectedDisplay.colorPreset)
  readonly property string unavailableReason: !available ? reason
    : !DisplayState.selectedDisplay ? "Select a display to adjust its colors."
    : DisplayState.selectedDisplay.disabled ? "Enable this display to adjust its colors."
    : !supported ? "Color adjustment is available for SDR displays. HDR uses its own color settings." : ""

  function adjustment(name) {
    if (pending && pending.name === name) return pending.value
    if (inFlight && inFlight.name === name) return inFlight.value
    return values[name] || { contrast: 1, saturation: 1, gamma: 1 }
  }
  function setValue(key, value) {
    if (!supported) return
    const next = Object.assign({}, adjustment(DisplayState.selectedName))
    next[key] = Math.round(value * 100) / 100
    pending = { name: DisplayState.selectedName, value: next }
    debounce.restart()
  }
  function reset() {
    if (!supported) return
    pending = { name: DisplayState.selectedName, value: { contrast: 1, saturation: 1, gamma: 1 } }
    debounce.restart()
  }
  function refresh() {
    if (worker.running || debounce.running) return
    worker.exec([script, "refresh"])
  }
  function applyPending() {
    if (worker.running || !pending) return
    inFlight = pending
    pending = null
    const v = inFlight.value
    worker.exec([script, "set", inFlight.name, String(v.contrast), String(v.saturation), String(v.gamma)])
  }
  Component.onCompleted: refresh()
  Timer { id: debounce; interval: 150; onTriggered: root.applyPending() }
  // Rebuild ID routing on hotplug and restore after a compositor config reload.
  Timer { interval: 4000; repeat: true; running: true; onTriggered: root.refresh() }
  Process {
    id: worker
    property string output: ""
    property string failure: ""
    onStarted: { output = ""; failure = "" }
    stdout: StdioCollector { onStreamFinished: worker.output = String(this.text) }
    stderr: StdioCollector { onStreamFinished: worker.failure = String(this.text) }
    onExited: function(code) {
      if (code === 0) {
        try {
          const data = JSON.parse(output)
          root.values = data.values
          root.available = data.available
          root.reason = data.reason
          root.error = ""
        } catch (e) { root.error = "Could not read color settings." }
      } else {
        root.error = "Could not apply color settings. " + failure.trim()
      }
      root.inFlight = null
      if (root.pending) debounce.restart()
    }
  }
}
