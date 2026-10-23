#!/usr/bin/env node
// Optional desktop check. Uses isolated copied configs and never runs power commands.
import assert from 'node:assert/strict'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { execFileSync, spawn } from 'node:child_process'
import { setTimeout as delay } from 'node:timers/promises'

const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..')
const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'kmdot-system-view-'))
const shell = path.join(temp, 'shell.qml')
let child
let log = ''
function ipc(method, ...args) {
  return execFileSync('qs', ['ipc', '-p', shell, 'call', '--', 'fixture', method, ...args], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim()
}
const state = () => JSON.parse(ipc('state'))
async function type(...args) {
  assert.equal(state().focused, true, 'Send keys only to the mapped, focused fixture')
  execFileSync('wtype', args)
  await delay(150)
}

try {
  fs.cpSync(path.join(repo, 'config/quickshell'), temp, { recursive: true })
  const palette = execFileSync(path.join(repo, 'theme-switcher/render-quickshell.sh'), [path.join(repo, 'themes/nord/quickshell.conf')])
  fs.writeFileSync(path.join(temp, 'Colors.qml'), palette)
  fs.writeFileSync(shell, `import QtQuick
import Quickshell
import Quickshell.Io
import "components"
import "menu"
Scope {
  id: fixture
  property var activeLauncher: null
  property var confirmPopup: confirmation
  property int commandCount: 0
  property string lastCommand: ""
  function closeAllExcept(except) {
    if (except !== system) system.closeLauncher()
    if (except !== legacy) legacy.closeLauncher()
    if (except !== confirmation) confirmation.close()
  }
  SystemLauncher {
    id: system
    scope: fixture
    sockName: "kmdot-system-fixture-${process.pid}"
    function runCommand(command) { fixture.commandCount++; fixture.lastCommand = command }
  }
  LauncherBase {
    id: legacy
    scope: fixture
    sockName: "kmdot-legacy-fixture-${process.pid}"
    items: [{label:"Legacy fixture"}]
  }
  ConfirmPopup { id: confirmation; scope: fixture }
  IpcHandler {
    target: "fixture"
    function open(): void { system.openLauncher() }
    function state(): string {
      var list = system.viewList
      var card = list ? list.parent.parent : null
      function child(name) { return card ? card.children.find(function(c) { return c.objectName === name }) : null }
      var header = child("castLauncherHeader"), footer = child("castLauncherFooter")
      var rows = list ? list.contentItem.children.filter(function(c) { return c.objectName === "castLauncherRow" }) : []
      return JSON.stringify({opened:system.opened,focused:system.viewInput && system.viewInput.activeFocus,
        query:system.query,index:system.selectedIndex,count:system.resultCount,
        selected:system.selectedItem ? system.selectedItem.label : "",commands:fixture.commandCount,
        confirmation:confirmation.opened,lastCommand:fixture.lastCommand,
        card:card ? {width:card.width,height:card.height,radius:card.radius,border:card.border.width} : null,
        header:header ? {height:header.height,y:header.y} : null,
        footer:footer ? {height:footer.height,y:footer.y} : null,
        rowHeights:rows.map(function(r) { return r.height }),font:system.viewInput.font.family,
        legacyStyle:legacy.castStyle,legacyFocused:legacy.viewInput && legacy.viewInput.activeFocus})
    }
    function activate(label: string): void {
      system.openLauncher()
      system.activateAt(system.results.findIndex(function(row) { return row.item.label === label }))
    }
    function legacyOpen(): void { legacy.openLauncher() }
    function legacyClose(): void { legacy.closeLauncher() }
  }
}`)
  child = spawn('quickshell', ['-n', '-p', shell], { stdio: ['ignore', 'pipe', 'pipe'] })
  child.stdout.on('data', d => { log += d })
  child.stderr.on('data', d => { log += d })
  let ready = false
  for (let i = 0; i < 50; i++) {
    try { state(); ready = true; break } catch {}
    await delay(100)
  }
  assert.ok(ready, log)
  ipc('open')
  await delay(300)
  const geometry = state()
  assert.deepEqual(geometry.card, { width: 680, height: 520, radius: 20, border: 1 })
  assert.equal(geometry.header.height, 64)
  assert.equal(geometry.footer.height, 40)
  assert.ok(geometry.rowHeights.length >= 5 && geometry.rowHeights.every(h => h === 56), JSON.stringify(geometry))
  assert.equal(geometry.count, 5)
  assert.equal(geometry.focused, true)
  await type('-k', 'Down')
  assert.equal(state().selected, 'Suspend')
  await type('-k', 'Up')
  assert.equal(state().selected, 'Lock')
  await type('restart')
  assert.equal(state().count, 1)
  assert.equal(state().selected, 'Restart')
  await type('-M', 'ctrl', '-s', '50', '-k', 'a', '-m', 'ctrl', '-k', 'BackSpace', 'zz-no-match')
  assert.equal(state().count, 0)
  await type('-k', 'Escape')
  assert.equal(state().opened, false)
  const actions = [
    ['Lock', '~/.config/kmdot/quickshell/scripts/lock-screen.sh'],
    ['Suspend', 'systemctl suspend'],
    ['Log out', "hyprctl dispatch 'hl.dsp.exit()'"],
    ['Restart', 'systemctl reboot'],
    ['Shut down', 'systemctl poweroff']
  ]
  for (const [index, [label, command]] of actions.entries()) {
    ipc('activate', label)
    assert.equal(state().opened, false)
    assert.equal(state().confirmation, false, `${label} must dispatch without a modal`)
    assert.equal(state().commands, index + 1)
    assert.equal(state().lastCommand, command)
  }
  ipc('legacyOpen')
  await delay(200)
  assert.equal(state().legacyStyle, false)
  assert.equal(state().legacyFocused, true)
  ipc('legacyClose')
  assert.ok(!/TypeError|ReferenceError|Cannot specify|Failed to load configuration/.test(log), log)
  console.log(JSON.stringify({geometry, checks:'search, empty results, arrows, Escape, all five actions dispatch immediately without a modal, legacy focus'}, null, 2))
} finally {
  if (child && child.exitCode === null) {
    child.kill('SIGTERM')
    await new Promise(resolve => child.once('exit', resolve))
  }
  fs.rmSync(temp, { recursive: true, force: true })
}
