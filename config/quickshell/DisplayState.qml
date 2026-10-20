pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

// Owns monitor discovery, display changes, persistence, and backlight state.
// UI code submits one intent at a time; Hyprland's actual monitor inventory is
// read back after each completed change and remains the source of truth.
Singleton {
  id: root

  property var displays: []
  property int selectedIdx: 0
  property string currentMode: "extend"
  property bool monitorsActive: false
  property bool changeBusy: false
  property string changeError: ""
  property var extendPositions: ({})

  readonly property var selectedDisplay: selectedIdx >= 0 && selectedIdx < displays.length
    ? displays[selectedIdx] : null
  readonly property string selectedName: selectedDisplay ? selectedDisplay.name : ""

  // Backlight cache is keyed by connector, then brightnessctl device.
  property var backlightMap: ({})
  property var deviceLevels: ({})
  property string _setDevice: ""
  property var _pendingSets: ({})
  property int _pollIdx: 0
  property string _gettingDevice: ""
  property var _maxQueue: []
  property string _maxDevice: ""

  readonly property bool selectedHasBacklight: selectedName in backlightMap
  readonly property string selectedDevice: selectedHasBacklight ? backlightMap[selectedName] : ""
  readonly property real selectedScale: selectedDisplay ? selectedDisplay.scale : 1
  readonly property string barDevice: {
    for (let i = 0; i < displays.length; i++)
      if (displays[i].focused && displays[i].name in backlightMap) return backlightMap[displays[i].name]
    for (let i = 0; i < displays.length; i++)
      if (displays[i].name in backlightMap) return backlightMap[displays[i].name]
    for (const connector in backlightMap) return backlightMap[connector]
    return ""
  }
  readonly property bool barHasBacklight: barDevice !== ""
  readonly property int barPercent: percentFor(barDevice)

  function curFor(device) {
    return device && device in deviceLevels ? deviceLevels[device].cur : 0
  }
  function maxFor(device) {
    return device && device in deviceLevels ? deviceLevels[device].max : 1
  }
  function percentFor(device) {
    const max = maxFor(device)
    return max > 0 ? Math.round(curFor(device) * 100 / max) : 0
  }
  function cacheLevel(device, cur, max) {
    const next = Object.assign({}, deviceLevels)
    const previous = next[device] || { cur: 0, max: 1 }
    next[device] = {
      cur: cur === undefined ? previous.cur : cur,
      max: max === undefined ? previous.max : max
    }
    deviceLevels = next
  }
  function applyBrightness(device, target) {
    if (!device) return
    const max = maxFor(device)
    const value = Math.max(Math.round(max * 0.05), Math.min(max, target))
    cacheLevel(device, value, undefined)
    if (_setDevice) {
      const pending = Object.assign({}, _pendingSets)
      pending[device] = value
      _pendingSets = pending
      return
    }
    _setDevice = device
    brightnessSetProc.exec(["brightnessctl", "--device", device, "set", String(value)])
  }
  function nudgeBar(direction) {
    const device = barDevice
    if (!device) return
    applyBrightness(device, curFor(device) + Math.max(1, Math.round(maxFor(device) * 0.05)) * direction)
  }

  // -- Monitor discovery --------------------------------------------------
  property bool _refreshAgain: false
  property bool _persistAfterRefresh: false
  property bool _rememberAfterRefresh: false

  function refreshDisplays() {
    if (changeBusy) {
      _refreshAgain = true
      return
    }
    if (monitorsProc.running) {
      _refreshAgain = true
      return
    }
    _refreshAgain = false
    monitorsProc.exec(["hyprctl", "monitors", "all", "-j"])
  }

  function _parseModes(values) {
    const modes = {}
    for (const raw of values || []) {
      const match = /^(\d+)x(\d+)@([\d.]+)Hz$/.exec(String(raw))
      if (!match) continue
      const mode = { width: Number(match[1]), height: Number(match[2]), refresh: Number(match[3]) }
      modes[mode.width + "x" + mode.height + "@" + mode.refresh.toFixed(2)] = mode
    }
    return Object.keys(modes).map(key => modes[key]).sort((a, b) =>
      (b.width * b.height - a.width * a.height) || b.refresh - a.refresh)
  }

  function _readMonitor(raw, inventory) {
    const modes = _parseModes(raw.availableModes)
    let width = Number(raw.width) || 0
    let height = Number(raw.height) || 0
    let refresh = Number(raw.refreshRate) || 60
    // Hyprland reports 0x0 for a disabled output even though it still exposes
    // availableModes. Keep a real mode in state so re-enabling it never emits
    // an invalid `mode = "0x0@…"` monitor rule.
    if (width <= 0 || height <= 0) {
      const fallback = modes.length ? modes[0] : null
      if (fallback) {
        width = fallback.width
        height = fallback.height
        refresh = fallback.refresh
      }
    }
    // Hyprland 0.56 reports the source monitor ID (including ID 0), not its
    // connector name. Normalize once so detection and confirmation agree.
    let mirrorOf = raw.mirrorOf === undefined || raw.mirrorOf === null ? "none" : String(raw.mirrorOf)
    if (mirrorOf !== "none" && mirrorOf !== "") {
      const source = (inventory || []).find(item => String(item.id) === mirrorOf || String(item.name) === mirrorOf)
      if (source) mirrorOf = String(source.name)
    } else mirrorOf = "none"
    return {
      name: String(raw.name),
      width: width,
      height: height,
      refresh: refresh,
      modes: modes,
      x: Number(raw.x) || 0,
      y: Number(raw.y) || 0,
      scale: Number(raw.scale) || 1,
      focused: !!raw.focused,
      disabled: !!raw.disabled,
      mirrorOf: mirrorOf
    }
  }

  function _internalName(items) {
    const monitors = items || displays
    for (const monitor of monitors)
      if (/^(eDP|LVDS|DSI)/i.test(monitor.name)) return monitor.name
    for (const monitor of monitors)
      if (monitor.name in backlightMap) return monitor.name
    return monitors.length ? monitors[0].name : "eDP-1"
  }
  function _isInternal(name) { return name === _internalName() }

  function _detectMode(items) {
    const internal = _internalName(items)
    if (items.some(monitor => !monitor.disabled && monitor.mirrorOf !== "none")) return "mirror"
    const laptop = items.find(monitor => monitor.name === internal)
    if (laptop && laptop.disabled && items.some(monitor => monitor.name !== internal && !monitor.disabled)) return "external"
    return "extend"
  }

  function _logicalWidth(monitor) { return monitor.width / (monitor.scale || 1) }
  function _logicalHeight(monitor) { return monitor.height / (monitor.scale || 1) }
  function _monitorExpectation(monitor) {
    return {
      name: monitor.name,
      width: monitor.width,
      height: monitor.height,
      x: Math.round(monitor.x),
      y: Math.round(monitor.y),
      scale: monitor.scale,
      disabled: !!monitor.disabled,
      mirrorOf: monitor.mirrorOf || "none"
    }
  }
  function _layoutValid(items) {
    const active = items.filter(monitor => !monitor.disabled && (!monitor.mirrorOf || monitor.mirrorOf === "none"))
    for (let i = 0; i < active.length; i++) {
      const a = active[i]
      for (let j = i + 1; j < active.length; j++) {
        const b = active[j]
        const apart = a.x + _logicalWidth(a) <= b.x || b.x + _logicalWidth(b) <= a.x
          || a.y + _logicalHeight(a) <= b.y || b.y + _logicalHeight(b) <= a.y
        if (!apart) return false
      }
    }
    return true
  }
  function _defaultExtendedLayout(items) {
    const ordered = items.map(monitor => Object.assign({}, monitor))
      .sort((a, b) => Number(_isInternal(b.name)) - Number(_isInternal(a.name)))
    let x = 0
    for (const monitor of ordered) {
      monitor.x = x
      monitor.y = 0
      monitor.disabled = false
      monitor.mirrorOf = "none"
      x += _logicalWidth(monitor)
    }
    return items.map(monitor => ordered.find(item => item.name === monitor.name))
  }
  function _extendedLayout(items) {
    const hasSaved = items.every(monitor => monitor.name in extendPositions)
    if (hasSaved) {
      const saved = items.map(monitor => Object.assign({}, monitor, {
        x: Number(extendPositions[monitor.name].x),
        y: Number(extendPositions[monitor.name].y),
        disabled: false,
        mirrorOf: "none"
      }))
      if (_layoutValid(saved)) return saved
    }
    const current = items.map(monitor => Object.assign({}, monitor, { disabled: false, mirrorOf: "none" }))
    if (_layoutValid(current)) return current
    return _defaultExtendedLayout(items)
  }
  function _rememberExtended(items) {
    const next = Object.assign({}, extendPositions)
    for (const monitor of items) next[monitor.name] = { x: Math.round(monitor.x), y: Math.round(monitor.y) }
    extendPositions = next
  }
  function _parkingPositions(items, names) {
    let x = 0
    for (const monitor of items) x = Math.max(x, monitor.x + _logicalWidth(monitor))
    x += 256
    const positions = ({})
    for (const name of names) {
      const monitor = items.find(item => item.name === name)
      positions[name] = { x: Math.ceil(x), y: 0 }
      x += _logicalWidth(monitor) + 64
    }
    return positions
  }
  function _loadExtendedPositions(text) {
    const result = ({})
    const regex = /^-- kmdot-extend-position: ([^|\n]+)\|(-?\d+)\|(-?\d+)$/gm
    let match
    while ((match = regex.exec(String(text))) !== null)
      result[match[1]] = { x: Number(match[2]), y: Number(match[3]) }
    extendPositions = result
  }

  function selectDisplay(index) {
    if (index >= 0 && index < displays.length) selectedIdx = index
  }

  // -- Sequenced monitor intent with compositor readback ------------------
  property var _queuedChange: null
  property var _activeChange: null

  function _luaString(value) { return JSON.stringify(String(value)) }
  function _monitorRule(monitor, patch) {
    const fields = [
      "output = " + _luaString(monitor.name),
      "mode = " + _luaString(monitor.width + "x" + monitor.height + "@" + Number(monitor.refresh).toFixed(2)),
      "position = " + _luaString(Math.round(monitor.x) + "x" + Math.round(monitor.y)),
      "scale = " + Number(monitor.scale)
    ]
    if (monitor.disabled) fields.push("disabled = true")
    else if (patch && patch.enable) fields.push("disabled = false")
    if (monitor.mirrorOf && monitor.mirrorOf !== "none") fields.push("mirror = " + _luaString(monitor.mirrorOf))
    else if (patch && patch.clearMirror) fields.push('mirror = ""')
    return "hl.monitor({ " + fields.join(", ") + " })"
  }

  function _submitMonitorChange(lua, nextDisplays, mode, recoverShell, saveLayout) {
    if (!lua) return
    if (nextDisplays) displays = nextDisplays
    if (mode) currentMode = mode
    changeError = ""
    _queuedChange = {
      steps: Array.isArray(lua) ? lua.slice() : [{ command: lua, expected: null }],
      stepIndex: 0,
      persist: true,
      saveLayout: !!saveLayout,
      recoverShell: !!recoverShell
    }
    _runQueuedChange()
  }

  function _runQueuedChange() {
    if (changeBusy || !_queuedChange) return
    _activeChange = _queuedChange
    _queuedChange = null
    changeBusy = true
    if (_activeChange.recoverShell) {
      // Spawn independently before changing outputs; Hyprland can briefly
      // remove every Wayland output and terminate this Quickshell process.
      shellRecoveryProc.exec(["sh", "-c", "setsid sh -c 'sleep 3; pgrep -x quickshell >/dev/null || setsid nohup quickshell >/dev/null 2>&1 </dev/null &' </dev/null >/dev/null 2>&1 &"])
    }
    _startMonitorStep()
  }

  function _startMonitorStep() {
    if (!_activeChange || _activeChange.stepIndex >= _activeChange.steps.length) return
    monitorChangeProc.exec(["hyprctl", "eval", _activeChange.steps[_activeChange.stepIndex].command])
  }

  function _advanceMonitorStep() {
    _activeChange.stepIndex += 1
    if (_activeChange.stepIndex < _activeChange.steps.length) {
      monitorStepTimer.restart()
      return
    }
    _persistAfterRefresh = !!_activeChange.persist
    _rememberAfterRefresh = !!_activeChange.saveLayout
    _activeChange = null
    _finishMonitorSequence()
  }

  function _checkMonitorStep() {
    const step = _activeChange ? _activeChange.steps[_activeChange.stepIndex] : null
    if (!step || !step.expected) {
      _advanceMonitorStep()
      return
    }
    monitorCheckAttempts = 0
    monitorCheckProc.exec(["hyprctl", "monitors", "all", "-j"])
  }

  function _monitorStepReadback(text) {
    const step = _activeChange ? _activeChange.steps[_activeChange.stepIndex] : null
    if (!step || !step.expected) return
    let actual = null
    try {
      const values = JSON.parse(String(text))
      const raw = values.find(item => String(item.name) === step.expected.name)
      if (raw) actual = _readMonitor(raw, values)
    } catch (error) {}
    const expected = step.expected
    const settled = actual && (expected.disabled
      ? actual.disabled
      : expected.mirrorOf !== "none"
        ? !actual.disabled && actual.mirrorOf === expected.mirrorOf
      : !actual.disabled
        && actual.x === expected.x && actual.y === expected.y
        && actual.width === expected.width && actual.height === expected.height
        && Math.abs(actual.scale - expected.scale) < 0.001
        && actual.mirrorOf === expected.mirrorOf)
    if (settled) {
      _advanceMonitorStep()
      return
    }
    if (monitorCheckAttempts++ < 12) {
      monitorCheckTimer.restart()
      return
    }
    changeError = "Hyprland did not settle " + expected.name + " at the requested position."
    _persistAfterRefresh = false
    _activeChange = null
    _finishMonitorSequence()
  }

  function applyDisplayMode(mode) {
    const selected = selectedDisplay
    if (!selected || !mode || changeBusy) return
    const next = displays.map(monitor => Object.assign({}, monitor))
    const changed = Object.assign({}, selected, {
      width: Number(mode.width), height: Number(mode.height), refresh: Number(mode.refresh)
    })
    next[selectedIdx] = changed
    _submitMonitorChange(_monitorRule(changed), next, "", false)
  }

  function applyScale(name, scale) {
    const index = displays.findIndex(monitor => monitor.name === name)
    if (index < 0 || changeBusy) return
    const next = displays.map(monitor => Object.assign({}, monitor))
    next[index].scale = Number(scale)
    _submitMonitorChange(_monitorRule(next[index]), next, "", false)
  }

  function setDisplayPosition(name, x, y) {
    const index = displays.findIndex(monitor => monitor.name === name)
    if (index < 0 || changeBusy || currentMode !== "extend") return
    const next = displays.map(monitor => Object.assign({}, monitor))
    next[index].x = Math.round(x)
    next[index].y = Math.round(y)
    if (!_layoutValid(next)) {
      changeError = "Displays cannot overlap. Drag the screen beside another display."
      return
    }
    _submitMonitorChange(_monitorRule(next[index]), next, "", false, true)
  }

  function applyMode(mode) {
    if (changeBusy || !["extend", "mirror", "external"].includes(mode) || mode === currentMode) return
    const current = displays.map(monitor => Object.assign({}, monitor))
    const internal = _internalName(current)
    const laptop = current.find(monitor => monitor.name === internal)
    const externals = current.filter(monitor => monitor.name !== internal)
    if (!laptop || (!externals.length && mode !== "extend")) return

    // Only an explicit arrangement edit replaces the saved Extend layout.
    // Mirroring and External mode may change the compositor's coordinates.
    if (!current.every(monitor => monitor.name in extendPositions)
        && currentMode === "extend" && current.every(monitor => !monitor.disabled && monitor.mirrorOf === "none")
        && _layoutValid(current)) _rememberExtended(current)
    const layout = _extendedLayout(current)
    const layoutByName = ({})
    for (const monitor of layout) layoutByName[monitor.name] = monitor
    const next = current.map(monitor => Object.assign({}, monitor))
    const targetLaptop = next.find(monitor => monitor.name === internal)
    const targetExternals = next.filter(monitor => monitor.name !== internal)
    const steps = []
    const add = (monitor, patch) => steps.push({
      command: _monitorRule(monitor, patch || { enable: true, clearMirror: true }),
      expected: _monitorExpectation(monitor)
    })
    const parks = _parkingPositions(current, externals.map(monitor => monitor.name).concat([internal]))

    if (mode === "external") {
      // First unmirror and park every output that might currently share a
      // mirrored position. Then arrange external outputs in a row before
      // disabling the internal panel.
      for (const monitor of targetExternals) {
        const park = parks[monitor.name]
        Object.assign(monitor, { x: park.x, y: park.y, disabled: false, mirrorOf: "none" })
        add(monitor, { enable: true, clearMirror: true })
      }
      const laptopPark = parks[internal]
      Object.assign(targetLaptop, { x: laptopPark.x, y: laptopPark.y, disabled: false, mirrorOf: "none" })
      add(targetLaptop, { enable: true, clearMirror: true })
      let x = 0
      for (const monitor of targetExternals) {
        monitor.x = Math.round(x); monitor.y = 0
        add(monitor, { enable: true, clearMirror: true })
        x += _logicalWidth(monitor)
      }
      targetLaptop.disabled = true
      targetLaptop.mirrorOf = "none"
      add(targetLaptop, {})
    } else if (mode === "mirror") {
      const ref = laptop.disabled ? layoutByName[internal] : laptop
      // An active source already has a stable input coordinate space. Leave
      // it in place; only stage outputs when the source must be re-enabled.
      if (laptop.disabled) {
        for (const monitor of targetExternals) {
          const park = parks[monitor.name]
          Object.assign(monitor, { x: park.x, y: park.y, disabled: false, mirrorOf: "none" })
          add(monitor, { enable: true, clearMirror: true })
        }
      }
      Object.assign(targetLaptop, { x: ref.x, y: ref.y, disabled: false, mirrorOf: "none" })
      if (laptop.disabled) add(targetLaptop, { enable: true, clearMirror: true })
      const pointer = "hl.dispatch(hl.dsp.focus({ monitor = " + _luaString(internal) + " })); "
        + "hl.dispatch(hl.dsp.cursor.move({ x = " + Math.round(ref.x + _logicalWidth(ref) / 2)
        + ", y = " + Math.round(ref.y + _logicalHeight(ref) / 2) + " }))"
      steps.push({ command: pointer, expected: null })
      for (const monitor of targetExternals) {
        Object.assign(monitor, { x: ref.x, y: ref.y, disabled: false, mirrorOf: internal })
        // A mirrored output is intentionally colocated with its source.
        add(monitor, { enable: true })
      }
      steps.push({ command: pointer, expected: null })
    } else {
      // Break any mirror relationship while the external outputs are safely
      // separated, then restore the last valid extended arrangement.
      for (const monitor of targetExternals) {
        const park = parks[monitor.name]
        Object.assign(monitor, { x: park.x, y: park.y, disabled: false, mirrorOf: "none" })
        add(monitor, { enable: true, clearMirror: true })
      }
      Object.assign(targetLaptop, layoutByName[internal], { disabled: false, mirrorOf: "none" })
      add(targetLaptop, { enable: true, clearMirror: true })
      for (const monitor of targetExternals) {
        const ref = layoutByName[monitor.name]
        Object.assign(monitor, { x: ref.x, y: ref.y, disabled: false, mirrorOf: "none" })
        add(monitor, { enable: true, clearMirror: true })
      }
    }
    _submitMonitorChange(steps, next, mode, true)
  }

  function _finishMonitorChange(exitCode) {
    const output = String(monitorChangeProc.stderrText || monitorChangeProc.stdoutText || "").trim()
    const rejected = /error|failed|invalid|unknown|not found/i.test(output)
    if (exitCode !== 0 || rejected) {
      changeError = output || "Hyprland could not apply that display change."
      _persistAfterRefresh = false
      _activeChange = null
      _finishMonitorSequence()
      return
    }

    _checkMonitorStep()
  }

  function _finishMonitorSequence() {
    changeBusy = false
    if (_queuedChange) {
      _runQueuedChange()
      return
    }
    refreshDisplays()
  }

  function _persistSettings() {
    const lines = []
    for (const name of Object.keys(extendPositions).sort()) {
      const pos = extendPositions[name]
      lines.push("-- kmdot-extend-position: " + name + "|" + pos.x + "|" + pos.y)
    }
    lines.push("return {")
    for (let i = 0; i < displays.length; i++) {
      const monitor = displays[i]
      lines.push("  " + _monitorRule(monitor).replace(/^hl\.monitor\(/, "").replace(/\)$/, "") + (i < displays.length - 1 ? "," : ""))
    }
    lines.push("}")
    settingsFile.setText(lines.join("\n") + "\n")
  }

  // -- Backlight discovery and polling ------------------------------------
  function detectBacklights() { backlightScanProc.exec(["sh", "-c",
    "for dev in /sys/class/backlight/*/; do " +
    "name=$(basename \"$dev\"); target=$(readlink -f \"${dev}device\" 2>/dev/null); " +
    "connector=$(echo \"$target\" | grep -oP 'card\\d+-\\K[A-Za-z0-9-]+$'); " +
    "[ -n \"$connector\" ] && echo \"$connector $name\"; done"])
  }

  Component.onCompleted: {
    detectBacklights()
    refreshDisplays()
  }

  onDisplaysChanged: {
    if (selectedIdx >= displays.length) selectedIdx = 0
  }

  Timer {
    interval: 4000
    repeat: true
    running: root.monitorsActive
    onTriggered: root.refreshDisplays()
  }
  Timer {
    interval: 700
    repeat: true
    running: true
    onTriggered: {
      const devices = Object.keys(root.backlightMap).map(connector => root.backlightMap[connector])
      if (!devices.length || backlightGetProc.running) return
      root._pollIdx = root._pollIdx % devices.length
      root._gettingDevice = devices[root._pollIdx++]
      backlightGetProc.exec(["brightnessctl", "--device", root._gettingDevice, "get"])
    }
  }

  Process {
    id: monitorsProc
    stdout: StdioCollector {
      onStreamFinished: {
        if (root.changeBusy) {
          root._refreshAgain = true
          return
        }
        if (root._refreshAgain) {
          root._refreshAgain = false
          root.refreshDisplays()
          return
        }
        try {
          const incoming = JSON.parse(String(this.text))
          const previousName = root.selectedName
          root.displays = incoming.map(raw => root._readMonitor(raw, incoming))
          const index = root.displays.findIndex(monitor => monitor.name === previousName)
          if (index >= 0) root.selectedIdx = index
          root.currentMode = root._detectMode(root.displays)
          if (root._rememberAfterRefresh) {
            root._rememberAfterRefresh = false
            if (root.currentMode === "extend" && root._layoutValid(root.displays))
              root._rememberExtended(root.displays)
          }
          if (root._persistAfterRefresh) {
            root._persistAfterRefresh = false
            root._persistSettings()
          }
        } catch (error) {
          root.changeError = "Could not read the connected display layout."
        }
      }
    }
  }
  Process {
    id: monitorChangeProc
    property string stdoutText: ""
    property string stderrText: ""
    stdout: StdioCollector { onStreamFinished: monitorChangeProc.stdoutText = String(this.text) }
    stderr: StdioCollector { onStreamFinished: monitorChangeProc.stderrText = String(this.text) }
    onStarted: { stdoutText = ""; stderrText = "" }
    onExited: function(exitCode) { root._finishMonitorChange(exitCode) }
  }
  Process {
    id: monitorCheckProc
    stdout: StdioCollector {
      onStreamFinished: root._monitorStepReadback(this.text)
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) root._monitorStepReadback("")
    }
  }
  Timer {
    id: monitorStepTimer
    interval: 175
    repeat: false
    onTriggered: root._startMonitorStep()
  }
  property int monitorCheckAttempts: 0
  Timer {
    id: monitorCheckTimer
    interval: 175
    repeat: false
    onTriggered: {
      if (root._activeChange) monitorCheckProc.exec(["hyprctl", "monitors", "all", "-j"])
    }
  }
  Process { id: shellRecoveryProc }
  Process { id: backlightScanProc; stdout: StdioCollector {
    onStreamFinished: {
      const next = {}
      for (const line of String(this.text).trim().split("\n")) {
        const parts = line.trim().split(/\s+/)
        if (parts.length === 2) next[parts[0]] = parts[1]
      }
      root.backlightMap = next
      const devices = Object.values(next).filter(device => !(device in root.deviceLevels))
      root._maxQueue = root._maxQueue.concat(devices)
      root._pumpBacklightMax()
    }
  } }
  Process {
    id: backlightGetProc
    stdout: StdioCollector {
      onStreamFinished: {
        const value = parseInt(String(this.text).replace(/[^0-9]/g, "")) || 0
        if (root._gettingDevice && root._setDevice !== root._gettingDevice)
          root.cacheLevel(root._gettingDevice, value, undefined)
      }
    }
  }
  Process {
    id: backlightMaxProc
    onExited: root._pumpBacklightMax()
    stdout: StdioCollector {
      onStreamFinished: {
        const value = parseInt(String(this.text).replace(/[^0-9]/g, "")) || 1
        if (root._maxDevice) root.cacheLevel(root._maxDevice, undefined, value)
      }
    }
  }
  function _pumpBacklightMax() {
    if (backlightMaxProc.running || !_maxQueue.length) return
    _maxDevice = _maxQueue[0]
    _maxQueue = _maxQueue.slice(1)
    backlightMaxProc.exec(["brightnessctl", "--device", _maxDevice, "max"])
  }
  Process {
    id: brightnessSetProc
    onExited: {
      const devices = Object.keys(root._pendingSets)
      if (!devices.length) { root._setDevice = ""; return }
      const device = devices[devices.length - 1]
      const target = root._pendingSets[device]
      const pending = Object.assign({}, root._pendingSets)
      delete pending[device]
      root._pendingSets = pending
      root._setDevice = device
      exec(["brightnessctl", "--device", device, "set", String(target)])
    }
  }
  FileView {
    id: settingsFile
    path: Quickshell.env("HOME") + "/.config/kmdot/display-settings.lua"
    watchChanges: false
    onLoaded: root._loadExtendedPositions(settingsFile.text())
  }
}
