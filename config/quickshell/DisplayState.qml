pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

// Single owner for all display state (issue #49).
// - Backlight detection (sysfs connector -> brightnessctl device map)
// - Per-device brightness levels with optimistic + coalesced sets
// - Monitor inventory from `hyprctl monitors -j`
// - hl.monitor rule building for extend / mirror / external + scale
// - Persisting display-settings.lua (consumed by hyprland/monitors.lua)
// Views (modules/Display.qml, menu/DisplayPopup.qml) bind to this and keep
// zero display-state Processes of their own.
Singleton {
  id: root

  // -- Monitor inventory -------------------------------------------------
  // Entries: { name, width, height, refresh, x, y, scale, focused }
  property var displays: []
  property var backlightMap: ({})
  property int selectedIdx: 0
  property string currentMode: "extend"
  property string externalPosition: "right" // "left" or "right"

  // Set by the popup: while true the monitor list refreshes every 5s.
  property bool monitorsActive: false

  readonly property var selectedDisplay: {
    if (selectedIdx >= 0 && selectedIdx < displays.length)
      return displays[selectedIdx]
    return null
  }
  readonly property string selectedName: selectedDisplay ? selectedDisplay.name : ""
  readonly property bool selectedHasBacklight: selectedName in backlightMap
  readonly property string selectedDevice: selectedHasBacklight ? backlightMap[selectedName] : ""
  readonly property real selectedScale: selectedDisplay ? selectedDisplay.scale : 1

  // -- Bar follow rule: focused display's device, else internal/first -----
  readonly property string _focusedName: {
    for (let i = 0; i < displays.length; i++) {
      if (displays[i].focused) return displays[i].name
    }
    return ""
  }
  readonly property string barDevice: {
    if (root._focusedName && root._focusedName in backlightMap)
      return backlightMap[root._focusedName]
    for (let i = 0; i < displays.length; i++) {
      const n = displays[i].name
      if (n in backlightMap) return backlightMap[n]
    }
    for (const k in backlightMap) return backlightMap[k]
    return ""
  }
  readonly property bool barHasBacklight: root.barDevice !== ""
  readonly property int barPercent: root.percentFor(root.barDevice)

  // -- Per-device brightness cache: { device: { cur, max } } --------------
  property var deviceLevels: ({})

  function curFor(device) {
    if (!device || !(device in deviceLevels)) return 0
    return deviceLevels[device].cur || 0
  }

  function maxFor(device) {
    if (!device || !(device in deviceLevels)) return 1
    return deviceLevels[device].max || 1
  }

  function percentFor(device) {
    const max = maxFor(device)
    return max > 0 ? Math.round(curFor(device) * 100 / max) : 0
  }

  function _setCached(device, cur, max) {
    const next = {}
    for (const k in deviceLevels) next[k] = deviceLevels[k]
    const prev = next[device] || { cur: 0, max: 1 }
    next[device] = {
      cur: cur !== undefined ? cur : prev.cur,
      max: max !== undefined ? max : prev.max
    }
    deviceLevels = next
  }

  // -- Detection + inventory ----------------------------------------------
  function refreshDisplays() {
    monitorsProc.exec(["sh", "-c", "hyprctl monitors -j"])
  }

  function detectBacklights() {
    backlightProc.exec(["sh", "-c",
      "for dev in /sys/class/backlight/*/; do " +
      "name=$(basename \"$dev\"); " +
      "target=$(readlink -f \"${dev}device\" 2>/dev/null); " +
      "connector=$(echo \"$target\" | grep -oP 'card\\d+-\\K[A-Za-z0-9-]+$'); " +
      "[ -n \"$connector\" ] && echo \"$connector $name\"; " +
      "done"])
  }

  // -- Brightness apply (optimistic + coalesced, 5% floor) -----------------
  property string _setDevice: ""
  property var _pendingSets: ({})

  function applyBrightness(device, target) {
    if (!device) return
    const max = maxFor(device)
    const min = Math.round(max * 5 / 100)
    const t = Math.max(min, Math.min(max, target))
    _setCached(device, t, undefined)
    if (root._setDevice !== "") {
      const pending = root._pendingSets
      pending[device] = t
      root._pendingSets = pending
      return
    }
    root._setDevice = device
    setProc.exec(["sh", "-c", "brightnessctl --device " + device + " set " + t])
  }

  // Wheel nudge for the bar: dir is +1 (up) or -1 (down), 5% of max.
  function nudgeBar(dir) {
    const device = root.barDevice
    if (!device) return
    const max = maxFor(device)
    const step = Math.max(1, Math.round(max * 5 / 100))
    applyBrightness(device, curFor(device) + dir * step)
  }

  // -- Monitor rules --------------------------------------------------------
  function _ruleFor(m, extra) {
    let rule = '{ output = "' + m.name + '", mode = "' + m.width + 'x' + m.height + '@' + m.refresh + '", position = "' + m.x + 'x' + m.y + '", scale = ' + m.scale
    if (extra) rule += ", " + extra
    return rule + " }"
  }

  function _internalName() {
    for (let i = 0; i < displays.length; i++) {
      if (displays[i].name in backlightMap) return displays[i].name
    }
    return displays.length > 0 ? displays[0].name : "eDP-1"
  }

  function applyScale(name, scale) {
    for (let i = 0; i < displays.length; i++) {
      if (displays[i].name === name) {
        const m = displays[i]
        const scaled = {
          name: m.name, width: m.width, height: m.height,
          refresh: m.refresh, x: m.x, y: m.y, scale: scale
        }
        _execRules(["hyprctl eval 'hl.monitor(" + _ruleFor(scaled, "") + ")'"])
        persistSettings()
        return
      }
    }
  }

  function applyMode(mode) {
    const internal = _internalName()
    const externals = []
    for (let i = 0; i < displays.length; i++) {
      if (displays[i].name !== internal) externals.push(displays[i])
    }
    // Refuse modes that need a second display (display-mode.sh exited 1 here).
    if ((mode === "mirror" || mode === "external") && externals.length === 0) return
    root.currentMode = mode
    const byName = {}
    for (let i = 0; i < displays.length; i++) byName[displays[i].name] = displays[i]

    const cmds = []
    if (mode === "extend") {
      let extW = 0
      for (let i = 0; i < externals.length; i++) extW += Math.round(externals[i].width / externals[i].scale)
      const intM = byName[internal]
      if (intM) {
        const ix = root.externalPosition === "left" ? extW : 0
        cmds.push("hyprctl eval 'hl.monitor(" + _ruleFor({
          name: intM.name, width: intM.width, height: intM.height,
          refresh: intM.refresh, x: ix, y: 0, scale: intM.scale
        }, "disabled = false") + ")'")
      }
      let ex = root.externalPosition === "left" ? 0 : (intM ? Math.round(intM.width / intM.scale) : 0)
      for (let i = 0; i < externals.length; i++) {
        const m = externals[i]
        cmds.push("hyprctl eval 'hl.monitor(" + _ruleFor({
          name: m.name, width: m.width, height: m.height,
          refresh: m.refresh, x: ex, y: 0, scale: m.scale
        }, "disabled = false") + ")'")
        ex += Math.round(m.width / m.scale)
      }
    } else if (mode === "mirror") {
      const intM = byName[internal]
      if (intM) cmds.push("hyprctl eval 'hl.monitor(" + _ruleFor(intM, "") + ")'")
      for (let i = 0; i < externals.length; i++) {
        cmds.push("hyprctl eval 'hl.monitor(" + _ruleFor(externals[i], 'mirror = "' + internal + '"') + ")'")
      }
    } else if (mode === "external") {
      cmds.push('hyprctl eval \'hl.monitor({ output = "' + internal + '", disabled = true })\'')
      for (let i = 0; i < externals.length; i++) {
        const m = externals[i]
        cmds.push("hyprctl eval 'hl.monitor(" + _ruleFor({
          name: m.name, width: m.width, height: m.height,
          refresh: m.refresh, x: 0, y: 0, scale: m.scale
        }, "") + ")'")
      }
    }
    if (cmds.length > 0) _execRules(cmds)
    persistSettings()
  }

  // Serialized rule executor: one hyprctl at a time, then refresh.
  property var _ruleQueue: []
  property bool _rulesBusy: false

  function _execRules(cmds) {
    root._ruleQueue = root._ruleQueue.concat(cmds)
    if (!root._rulesBusy) {
      root._rulesBusy = true
      _runNextRule()
    }
  }

  function _runNextRule() {
    if (root._ruleQueue.length === 0) {
      root._rulesBusy = false
      refreshDisplays()
      return
    }
    const cmd = root._ruleQueue[0]
    root._ruleQueue = root._ruleQueue.slice(1)
    ruleProc.exec(["sh", "-c", cmd])
  }

  // -- Persist (FileView, coalesced; format consumed by monitors.lua) ------
  property bool _persistDirty: false

  function persistSettings() {
    root._persistDirty = true
    persistTimer.restart()
  }

  function _buildLua() {
    const lines = ["return {"]
    for (let i = 0; i < displays.length; i++) {
      const m = displays[i]
      const isExternal = !(m.name in backlightMap)
      const scale = (m.name === selectedName) ? selectedScale : m.scale
      let rule = '  { output = "' + m.name + '", mode = "' + m.width + 'x' + m.height + '@' + m.refresh + '", position = "' + m.x + 'x' + m.y + '", scale = ' + scale
      if (currentMode === "external" && !isExternal) rule += ", disabled = true"
      if (currentMode === "mirror" && isExternal && displays.length > 0) rule += ', mirror = "' + displays[0].name + '"'
      rule += " }"
      if (i < displays.length - 1) rule += ","
      lines.push(rule)
    }
    lines.push("}")
    lines.push("-- external_position: " + root.externalPosition)
    return lines.join("\n") + "\n"
  }

  function _doPersist() {
    root._persistDirty = false
    persistView.setText(_buildLua())
  }

  Component.onCompleted: {
    detectBacklights()
    refreshDisplays()
  }

  onDisplaysChanged: {
    if (root.selectedIdx >= displays.length) root.selectedIdx = 0
  }

  // Hotplug: re-detect when the screen count changes.
  property int _seenScreens: -1
  Timer {
    interval: 3000
    running: true
    repeat: true
    onTriggered: {
      const n = Quickshell.screens.values.length
      if (root._seenScreens !== -1 && n !== root._seenScreens) {
        root.detectBacklights()
        root.refreshDisplays()
      }
      root._seenScreens = n
    }
  }

  // Single always-on brightness poller, round-robin over devices.
  property int _pollIdx: 0
  property string _gettingDevice: ""
  Timer {
    interval: 500
    running: true
    repeat: true
    onTriggered: {
      const devs = []
      for (const k in root.backlightMap) devs.push(root.backlightMap[k])
      if (devs.length === 0 || getProc.running) return
      root._pollIdx = root._pollIdx % devs.length
      const d = devs[root._pollIdx]
      root._pollIdx++
      root._gettingDevice = d
      getProc.exec(["sh", "-c", "brightnessctl --device " + d + " get"])
    }
  }

  // Monitor inventory refresh, only while the popup is open.
  Timer {
    interval: 5000
    running: root.monitorsActive
    repeat: true
    onTriggered: root.refreshDisplays()
  }

  Timer {
    id: persistTimer
    interval: 300
    repeat: false
    onTriggered: root._doPersist()
  }

  // Fetch max for newly seen devices, one at a time.
  property var _maxQueue: []
  property string _maxDevice: ""
  function _pumpMaxQueue() {
    if (root._maxQueue.length === 0 || maxProc.running) return
    const d = root._maxQueue[0]
    root._maxQueue = root._maxQueue.slice(1)
    root._maxDevice = d
    maxProc.exec(["sh", "-c", "brightnessctl --device " + d + " max"])
  }

  Process {
    id: backlightProc
    stdout: StdioCollector {
      onStreamFinished: {
        const map = {}
        const lines = this.text.trim().split("\n")
        for (let i = 0; i < lines.length; i++) {
          const parts = lines[i].split(" ")
          if (parts.length >= 2) map[parts[0]] = parts[1]
        }
        root.backlightMap = map
        const q = []
        for (const k in map) {
          if (!(map[k] in root.deviceLevels)) q.push(map[k])
        }
        if (q.length > 0) {
          root._maxQueue = root._maxQueue.concat(q)
          root._pumpMaxQueue()
        }
      }
    }
  }

  Process {
    id: monitorsProc
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const arr = JSON.parse(this.text)
          const result = []
          for (let i = 0; i < arr.length; i++) {
            const m = arr[i]
            result.push({
              name: m.name,
              width: m.width,
              height: m.height,
              refresh: m.refreshRate ? Math.round(m.refreshRate) : 60,
              x: m.x,
              y: m.y,
              scale: m.scale || 1,
              focused: m.focused || false
            })
          }
          root.displays = result
        } catch (e) {}
      }
    }
  }

  Process {
    id: getProc
    stdout: StdioCollector {
      onStreamFinished: {
        const v = parseInt(this.text.replace(/[^0-9]/g, "")) || 0
        if (root._gettingDevice && root._setDevice !== root._gettingDevice)
          root._setCached(root._gettingDevice, v, undefined)
      }
    }
  }

  Process {
    id: maxProc
    stdout: StdioCollector {
      onStreamFinished: {
        const v = parseInt(this.text.replace(/[^0-9]/g, "")) || 1
        if (root._maxDevice) root._setCached(root._maxDevice, undefined, v)
      }
    }
    onExited: root._pumpMaxQueue()
  }

  Process {
    id: setProc
    onExited: {
      const keys = Object.keys(root._pendingSets)
      if (keys.length > 0) {
        const device = keys[keys.length - 1]
        const t = root._pendingSets[device]
        const pending = root._pendingSets
        delete pending[device]
        root._pendingSets = pending
        root._setDevice = device
        setProc.exec(["sh", "-c", "brightnessctl --device " + device + " set " + t])
      } else {
        root._setDevice = ""
      }
    }
  }

  Process {
    id: ruleProc
    onExited: root._runNextRule()
  }

  FileView {
    id: persistView
    path: Quickshell.env("HOME") + "/.config/kmdot/display-settings.lua"
    watchChanges: false
    onLoaded: {
      const m = /-- external_position:\s*(left|right)/.exec(persistView.text())
      if (m) root.externalPosition = m[1]
    }
    // Missing file on first run is fine: leave defaults, write on action.
    onLoadFailed: {}
  }
}
