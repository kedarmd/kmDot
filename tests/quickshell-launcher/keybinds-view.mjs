#!/usr/bin/env node
// Real Lua inspection and QML rendering against isolated shortcut data.
import assert from 'node:assert/strict'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { execFileSync, spawn } from 'node:child_process'
import { setTimeout as delay } from 'node:timers/promises'

const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..')
const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'kmdot-keybinds-view-'))
const shell = path.join(temp, 'shell.qml')
const runtimeFile = path.join(temp, 'runtime-bindings.json')
let child, log = ''
const ipc = method => execFileSync('qs', ['ipc', '-p', shell, 'call', '--', 'fixture', method], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim()
const state = () => JSON.parse(ipc('state'))
async function key(...args) {
  assert.equal(state().focused, true)
  execFileSync('wtype', args)
  await delay(150)
}

try {
  fs.cpSync(path.join(repo, 'config/quickshell'), temp, { recursive: true })
  const palette = path.join(temp, 'Colors.qml')
  fs.writeFileSync(palette, execFileSync(path.join(repo, 'theme-switcher/render-quickshell.sh'), [path.join(repo, 'themes/everforest/quickshell.conf')]))
  const home = path.join(temp, 'home')
  const hypr = path.join(home, '.config/kmdot/hyprland')
  fs.mkdirSync(path.join(hypr, 'scripts'), { recursive: true })
  fs.copyFileSync(path.join(repo, 'config/hyprland/scripts/keybinds.lua'), path.join(hypr, 'scripts/keybinds.lua'))
  fs.writeFileSync(path.join(hypr, 'keybinds.lua'), `local mod = "SUPER"
hl.bind(mod .. " + SPACE", hl.dsp.exec_cmd("toggle.sh kmdot-launcher")) -- Open app launcher
hl.bind(mod .. " + T", hl.dsp.exec_cmd("toggle.sh kmdot-theme")) -- Theme switcher
hl.bind(mod .. " + SHIFT + P", hl.dsp.exec_cmd("toggle.sh kmdot-clipboard")) -- Clipboard history
hl.bind(mod .. " + left", hl.dsp.focus({direction="left"})) -- Focus window left
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("unused"), {repeating=true}) -- Raise volume
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), {mouse=true}) -- Drag window with mouse
for i=1,2 do
  hl.bind(mod .. " + " .. i, hl.dsp.focus({workspace=i})) -- Switch to workspace
end
hl.bind(mod .. " + K", hl.dsp.exec_cmd("unused")) -- Not registered in runtime
`)
  const runtime = [
    { modmask: 64, key: 'SPACE' }, { modmask: 64, key: 'T' },
    { modmask: 65, key: 'P' }, { modmask: 64, key: 'left' },
    { modmask: 0, key: 'XF86AudioRaiseVolume', repeat: true }, { modmask: 64, key: 'mouse:272' },
    { modmask: 64, key: '1' }, { modmask: 64, key: '2' },
    { modmask: 0, key: 'F9', description: 'Temporary runtime action' },
    { modmask: 0, key: 'F10' }
  ]
  for (let i = 0; i < 80; i++) runtime.push({ modmask: 0, key: 'RuntimeKey' + i, description: 'Runtime action ' + i })
  fs.writeFileSync(runtimeFile, JSON.stringify(runtime))
  const bin = path.join(temp, 'bin')
  fs.mkdirSync(bin)
  fs.writeFileSync(path.join(bin, 'hyprctl'), '#!/usr/bin/env bash\ncat -- "$KMDOT_KEYBINDS_FIXTURE"\n', { mode: 0o755 })
  fs.writeFileSync(shell, `import QtQuick
import Quickshell
import Quickshell.Io
import "menu"
Scope {
  id: fixture
  property int activations: 0
  property int poolChanges: 0
  KeybindsLauncher {
    id: picker
    sockName: "keybinds-fixture-${process.pid}"
    onActivated: fixture.activations++
  }
  Connections { target: picker; function onPoolChanged() { fixture.poolChanges++ } }
  function all(name,item) {
    var out=item.objectName===name ? [item] : []
    for(var c of item.children||[]) out=out.concat(all(name,c))
    return out
  }
  IpcHandler {
    target: "fixture"
    function open(): void { picker.openLauncher() }
    function state(): string {
      var card=picker.viewList.parent.parent,origin=card.mapToGlobal(0,0)
      var footer=all("castLauncherFooterActions",card)[0]
      var keys=all("castLauncherShortcutKeys",card).filter(function(k){return k.visible})
      return JSON.stringify({opened:picker.opened,focused:picker.viewInput.activeFocus,
        count:picker.resultCount,selected:picker.selectedItem ? picker.selectedItem.label:"",error:picker.listErrorText,
        activations:fixture.activations,readonly:!picker.deactivatable,poolChanges:fixture.poolChanges,
        shortcuts:picker.pool.map(function(row){return {label:row.label,keys:row.meta}}),
        keycaps:keys.map(function(k){return k.keys}),
        keycapsFit:keys.every(function(k){var p=k.mapToItem(card,0,0);return p.x>=24 && p.x+k.width<=card.width-12}),
        enterHint:footer.children.some(function(c){return c.visible && c.keys==="↵"}),
        card:{width:card.width,height:card.height,radius:card.radius,x:origin.x,y:origin.y}})
    }
  }
}`)
  child = spawn('quickshell', ['-n', '-p', shell], {
    env: { ...process.env, HOME: home, KMDOT_LAUNCHER_THEME_FILE: palette,
      KMDOT_KEYBINDS_FIXTURE: runtimeFile, PATH: bin + ':' + process.env.PATH },
    stdio: ['ignore', 'pipe', 'pipe']
  })
  child.stdout.on('data', d => { log += d })
  child.stderr.on('data', d => { log += d })
  let ready = false
  for (let i = 0; i < 50; i++) {
    try { state(); ready = true; break } catch {}
    await delay(100)
  }
  assert.ok(ready, log)
  ipc('open')
  for (let i = 0; i < 40 && state().count !== runtime.length; i++) await delay(100)
  await delay(250)
  const geometry = state()
  assert.equal(geometry.card.width, 680)
  assert.equal(geometry.card.height, 520)
  assert.equal(geometry.card.radius, 20)
  assert.equal(geometry.count, runtime.length, JSON.stringify(geometry))
  assert.ok(geometry.readonly && geometry.keycapsFit && !geometry.enterHint)
  assert.ok(geometry.keycaps.length > 0)
  assert.equal(geometry.shortcuts.find(s => s.label === 'Clipboard history').keys, 'Super Shift P')
  assert.ok(geometry.shortcuts.some(s => s.label === 'Theme switcher'))
  assert.ok(geometry.shortcuts.some(s => s.label === 'Temporary runtime action'))
  assert.ok(geometry.shortcuts.some(s => s.label === 'Custom shortcut'))
  assert.equal(geometry.shortcuts.filter(s => s.label === 'Switch to workspace').length, 2)
  assert.ok(!geometry.shortcuts.some(s => s.label === 'Not registered in runtime'))
  execFileSync('grim', ['-g', `${geometry.card.x},${geometry.card.y} 680x520`, path.join(os.tmpdir(), 'kmdot-keybinds-review.png')])
  await key('-k', 'Down')
  assert.equal(state().selected, 'Theme switcher')
  await key('clipboard')
  assert.equal(state().count, 1)
  assert.equal(state().selected, 'Clipboard history')
  await key('-k', 'Return')
  assert.equal(state().opened, true)
  assert.equal(state().activations, 0)
  await key('-M', 'ctrl', '-s', '50', '-k', 'a', '-m', 'ctrl', '-k', 'BackSpace', 'super+t')
  assert.equal(state().selected, 'Theme switcher')
  assert.equal(state().count, 1)
  const changes = state().poolChanges
  await delay(2200)
  assert.equal(state().poolChanges, changes, 'An unchanged poll must not reset the list')
  runtime.push({ modmask: 0, key: 'F11', description: 'New runtime binding' })
  fs.writeFileSync(runtimeFile, JSON.stringify(runtime))
  for (let i = 0; i < 40 && !state().shortcuts.some(s => s.label === 'New runtime binding'); i++) await delay(100)
  assert.ok(state().shortcuts.some(s => s.label === 'New runtime binding'))
  assert.equal(state().selected, 'Theme switcher')
  fs.writeFileSync(runtimeFile, '{invalid JSON')
  for (let i = 0; i < 40 && state().shortcuts.length !== 0; i++) await delay(100)
  assert.equal(state().shortcuts.length, 0, 'Query failure must not invent fallback bindings')
  fs.writeFileSync(runtimeFile, JSON.stringify(runtime))
  for (let i = 0; i < 40 && state().shortcuts.length !== runtime.length; i++) await delay(100)
  assert.equal(state().shortcuts.length, runtime.length)
  await key('-M', 'ctrl', '-s', '50', '-k', 'a', '-m', 'ctrl', '-k', 'BackSpace', 'zz-no-match')
  assert.equal(state().count, 0)
  await key('-k', 'Escape')
  assert.equal(state().opened, false)
  assert.ok(!/TypeError|ReferenceError|Cannot specify|Failed to load configuration/.test(log), log)
  console.log(JSON.stringify({geometry, checks:'live-only inventory, real Lua comments/loops, dynamic runtime additions, unchanged-poll stability, key search, query failure/recovery and read-only behavior'}, null, 2))
} finally {
  if (child && child.exitCode === null) {
    child.kill('SIGTERM')
    await new Promise(resolve => child.once('exit', resolve))
  }
  fs.rmSync(temp, { recursive: true, force: true })
}
