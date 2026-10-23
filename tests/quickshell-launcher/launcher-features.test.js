const test = require("node:test")
const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const vm = require("node:vm")

const source = fs.readFileSync(path.join(__dirname, "../../config/quickshell/launcher/plugin/ui/LauncherWindow.qml"), "utf8")
function body(signature) {
  const start = source.indexOf(signature)
  assert.ok(start >= 0, signature)
  const open = source.indexOf("{", start) + 1
  const end = source.indexOf("\n  }", open)
  return "(function() {\n" + source.slice(open, end) + "\n})()"
}

function harness(text) {
  const changes = []
  const window = {
    query: "before ", actionPanelOpen: false, view: { kind: "root" }, argFocus: -1,
    argDefs: [], argValues: {}, setQuery(value) { this.query = value; changes.push(value) }
  }
  const actionPanel = { filter: "" }
  const context = vm.createContext({ window, actionPanel, Quickshell: { clipboardText: text } })
  window.pasteClipboard = () => vm.runInContext(body("function pasteClipboard()"), context)
  return { window, actionPanel, changes, press(key, modifiers) {
    const Qt = { NoModifier: 0, ShiftModifier: 2, ControlModifier: 1, AltModifier: 4, MetaModifier: 8,
      Key_Escape: 27, Key_V: 86, Key_Insert: 45, Key_Plus: 43, Key_Equal: 61, Key_Minus: 45, Key_0: 48, Key_BracketLeft: 91,
      Key_K: 75, Key_P: 80, Key_T: 84, Key_Return: 13, Key_Enter: 13, Key_J: 74, Key_N: 78, Key_Up: 38, Key_Down: 40,
      Key_F: 70, Key_C: 67, Key_D: 68, Key_1: 49, Key_9: 57, Key_Tab: 9, Key_Backtab: 10, Key_Backspace: 8, Key_Delete: 46 }
    const event = { key: Qt[key], modifiers, text: "" }
    const context = vm.createContext({ window: Object.assign(window, {
      handleEscape() {}, setZoom() {}, closePopups() {}, pop() {}, pasteClipboard: window.pasteClipboard,
      isActionPanelKey: () => false, isTyping: () => false, direction: () => 0,
      toggleActionPanel() {}, toggleAbout() {}, toggleDropdown() {}, toggleToastPanel() {},
      performNth() {}, performIfOffered() {}, perform() {}, move() {}, recallHistory() { return false },
      jumpSection() {}, nthItem() { return -1 }, argDefs: window.argDefs, argFocus: window.argFocus,
      atRoot: true, historyIndex: -1, selectedIndex: 0, nextSelectable() { return 1 },
      query: window.query, view: window.view
    }), Qt, Util: { editsFilter: () => false, editedFilter: (e, q) => q }, actionPanel, Quickshell: { clipboardText: text } })
    context.event = event
    return vm.runInContext(body("function handleKey(event)"), context)
  } }
}

test("clipboard paste is plain text and routes to the active kmdot-launcher field", () => {
  const h = harness("<b>你好</b> $(id)\r\nsecond\u2028third")
  h.window.pasteClipboard()
  assert.deepEqual(h.changes, ["before <b>你好</b> $(id) second third"])

  const args = harness("km dot")
  args.window.argDefs = [{ name: "query" }]
  args.window.argFocus = 0
  args.window.argValues = { query: "web " }
  args.window.pasteClipboard()
  assert.equal(args.window.argValues.query, "web km dot")
  assert.deepEqual(args.changes, [])

  const action = harness("Copy Result")
  action.window.actionPanelOpen = true
  action.actionPanel.filter = "Find "
  action.window.pasteClipboard()
  assert.equal(action.actionPanel.filter, "Find Copy Result")
})

test("Ctrl+V routes to the launcher clipboard handler", () => {
  const h = harness("pasted")
  h.press("Key_V", 1)
  assert.deepEqual(h.changes, ["before pasted"])
})

test('the displayed Actions chord opens and closes Actions without changing the search', () => {
  const Qt = { Key_K: 75, ControlModifier: 0x04000000, ShiftModifier: 0x02000000,
    AltModifier: 0x08000000, MetaModifier: 0x10000000 }
  const actionPanel = { filter: 'stale action filter' }
  const window = { vim: true, atRoot: true, view: { kind: 'root' }, query: 'keep this search',
    actionPanelOpen: false, actionsForSelected: () => [{ id: 'open', title: 'Open' }] }
  const context = vm.createContext({ window, Qt, actionPanel })
  window.isActionPanelKey = (ctrl, alt, shift, key) => {
    Object.assign(context, { ctrl, alt, shift, key })
    return vm.runInContext(body('function isActionPanelKey(ctrl, alt, shift, key)'), context)
  }
  window.toggleActionPanel = () => vm.runInContext(body('function toggleActionPanel()'), context)
  for (const [vim, modifiers] of [[true, Qt.AltModifier], [false, Qt.ControlModifier]]) {
    window.vim = vim
    context.event = { key: Qt.Key_K, modifiers, text: 'k' }
    assert.equal(vm.runInContext(body('function handleKey(event)'), context), true)
    assert.equal(window.actionPanelOpen, true)
    assert.equal(window.actions.length, 1)
    assert.equal(actionPanel.filter, '')
    assert.equal(window.query, 'keep this search')
    assert.equal(vm.runInContext(body('function handleKey(event)'), context), true)
    assert.equal(window.actionPanelOpen, false)
    assert.equal(window.query, 'keep this search')
  }
})

test("the Escape hint and root filter have separate header space", () => {
  assert.match(source, /anchors\.right:\s*filterButton\.visible\s*\?\s*filterButton\.left\s*:\s*parent\.right/)
  assert.match(source, /queryRoom:[^\n]*escapeHint\.width/)
})

test("explicit filter entry resets a stale subview and query before showing applications", () => {
  const window = {
    query: 'old query', rootFilter: 'commands', stack: [{ kind: 'root' }, { kind: 'alias' }],
    historyIndex: 3,
    popToRoot() { this.stack = [{ kind: 'root' }]; this.query = ''; this.rootFilter = 'all' },
    closePopups() {}, rebuild() {}
  }
  const context = vm.createContext({ window, payload: { filter: 'applications' },
    RootSearch: require('../../config/quickshell/launcher/plugin/core/RootSearch.js'),
    popTimer: { stop() {} }, Qt: { callLater() {} }, keyCatcher: {} })
  vm.runInContext(body('function prepare(payload)'), context)
  assert.equal(window.rootFilter, 'applications')
  assert.equal(window.stack.length, 1)
  assert.equal(window.query, '')
  assert.equal(window.historyIndex, -1)
  context.payload = { filter: 'unsupported' }
  vm.runInContext(body('function prepare(payload)'), context)
  assert.equal(window.rootFilter, 'all')
})
