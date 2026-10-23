#!/usr/bin/env node
// Native QML/keyboard check with a fake Wifi singleton: no radio/network changes.
import assert from 'node:assert/strict'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { execFileSync, spawn } from 'node:child_process'
import { setTimeout as delay } from 'node:timers/promises'

const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..')
const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'kmdot-wifi-view-'))
const shell = path.join(temp, 'shell.qml')
let child, log = ''
const ipc = (method, ...args) => execFileSync('qs', ['ipc', '-p', shell, 'call', '--', 'fixture', method, ...args], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim()
const state = () => JSON.parse(ipc('state'))
async function key(...args) {
  assert.equal(state().focused, true, 'Send keys only to the focused fixture')
  execFileSync('wtype', args)
  await delay(150)
}
async function open(query = '') {
  ipc('open')
  await delay(350)
  if (query) await key(query)
}
function capture(name) {
  const s = state()
  execFileSync('grim', ['-g', `${s.card.x},${s.card.y} ${s.card.width}x${s.card.height}`, path.join(os.tmpdir(), name)])
}

try {
  fs.cpSync(path.join(repo, 'config/quickshell'), temp, { recursive: true })
  fs.writeFileSync(path.join(temp, 'Colors.qml'), execFileSync(path.join(repo, 'theme-switcher/render-quickshell.sh'), [path.join(repo, 'themes/everforest/quickshell.conf')]))
  fs.writeFileSync(path.join(temp, 'Wifi.qml'), `pragma Singleton
import QtQuick
QtObject {
  id: store
  property bool enabled: true
  property bool scanning: false
  property string errorText: ""
  property string busySsid: ""
  property var calls: []
  property var networks: sample()
  function sample() { var rows = [
    {ssid:"Current network",active:true,saved:true,open:false,signal:90,security:"WPA2"},
    {ssid:"Saved network",active:false,saved:true,open:false,signal:75,security:"WPA2"},
    {ssid:"Open network",active:false,saved:false,open:true,signal:65,security:""},
    {ssid:"Private: network",active:false,saved:false,open:false,signal:55,security:"WPA2"}
  ]; for(var i=1;i<=12;i++) rows.push({ssid:"Nearby network "+i,active:false,saved:false,open:false,signal:40-i,security:"WPA2"}); return rows }
  function scan() {}
  function isSaved(ssid) { return networks.some(function(n) { return n.ssid===ssid && n.saved }) }
  function connect(item, password) {
    calls=calls.concat([{verb:"connect",ssid:item.ssid,hasPassword:password!==undefined}])
    if (password!==undefined) busySsid=item.ssid
    return true
  }
  function disconnect(item) { calls=calls.concat([{verb:"disconnect",ssid:item.ssid}]) }
  function toggleRadio() { enabled=!enabled; networks=enabled ? sample() : [] }
  function forget(ssid) { calls=calls.concat([{verb:"forget",ssid:ssid}]); networks=networks.filter(function(n){return n.ssid!==ssid}) }
  function fail() { errorText="The password was not accepted"; busySsid="" }
  function succeed() { busySsid="" }
  function loading() { scanning=true; networks=[] }
}`)
  fs.writeFileSync(shell, `import QtQuick
import Quickshell
import Quickshell.Io
import "menu"
Scope {
  id: fixture
  property var activeLauncher: null
  property var confirmPopup: confirmation
  function closeAllExcept(except) { if(except!==picker)picker.closeLauncher(); if(except!==confirmation)confirmation.close() }
  WifiLauncher { id: picker; scope: fixture; sockName: "wifi-fixture-${process.pid}" }
  ConfirmPopup { id: confirmation; scope: fixture }
  function find(name,item) { if(item.objectName===name)return item; for(var c of item.children||[]){var f=find(name,c);if(f)return f} return null }
  IpcHandler {
    target: "fixture"
    function open(): void { picker.openLauncher() }
    function fail(): void { Wifi.fail() }
    function succeed(): void { Wifi.succeed() }
    function loading(): void { Wifi.loading() }
    function clickToggle(): void { find("castLauncherHeaderAction",picker.viewList.parent.parent).clicked() }
    function state(): string {
      var card=picker.viewList.parent.parent
      var action=find("castLauncherHeaderAction",card)
      var footer=find("castLauncherFooterActions",card)
      var prompt=find("castLauncherPasswordPrompt",card)
      var origin=card.mapToGlobal(0,0)
      return JSON.stringify({opened:picker.opened,focused:confirmation.opened ? confirmation.focusItem.activeFocus : picker.viewInput.activeFocus,
        count:picker.resultCount,selected:picker.selectedItem ? picker.selectedItem.label:"",loading:picker.loading,empty:picker.emptyText,
        prompt:picker.promptMode,promptVisible:prompt.visible,error:picker.promptError,
        masked:picker.viewInput.echoMode===TextInput.Password,passwordEmpty:picker.viewInput.text.length===0,
        enabled:Wifi.enabled,headerAction:action.text,primary:picker.primaryActionText,
        footerFits:footer.x>=90 && footer.x+footer.width<=card.width,
        scrollbar:find("castLauncherScrollbar",card).visible,
        confirmation:confirmation.opened,calls:Wifi.calls,
        card:{width:card.width,height:card.height,radius:card.radius,x:origin.x,y:origin.y}})
    }
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
  await open()
  const geometry = state()
  assert.equal(geometry.card.width, 680)
  assert.equal(geometry.card.height, 520)
  assert.equal(geometry.card.radius, 20)
  assert.ok(geometry.footerFits)
  assert.equal(geometry.scrollbar, true)
  assert.equal(geometry.headerAction, 'Wi-Fi on')
  assert.equal(geometry.primary, 'Disconnect')
  capture('kmdot-wifi-list.png')
  await key('-k', 'Return')
  assert.equal(state().calls.at(-1).verb, 'disconnect')
  assert.equal(state().opened, false)
  for (const query of ['Saved network', 'Open network']) {
    await open(query)
    assert.ok(state().footerFits)
    await key('-k', 'Return')
    assert.deepEqual(state().calls.at(-1), { verb: 'connect', ssid: query, hasPassword: false })
  }
  await open('Private: network')
  await key('-k', 'Return')
  assert.ok(state().prompt && state().promptVisible && state().masked)
  assert.equal(state().scrollbar, false)
  await key('fixture-password', '-k', 'Return')
  assert.deepEqual(state().calls.at(-1), { verb: 'connect', ssid: 'Private: network', hasPassword: true })
  ipc('fail')
  await delay(100)
  assert.ok(state().prompt && state().masked && state().passwordEmpty)
  assert.ok(state().error.includes('not accepted'))
  capture('kmdot-wifi-password.png')
  await key('fixture-password', '-k', 'Return')
  ipc('succeed')
  assert.equal(state().opened, false)
  await open('Private: network')
  await key('-k', 'Return')
  await key('-k', 'Escape')
  assert.equal(state().prompt, false)
  assert.equal(state().opened, true)
  ipc('clickToggle')
  assert.equal(state().enabled, false)
  assert.equal(state().count, 0)
  assert.equal(state().empty, 'Wi-Fi is turned off')
  await key('-k', 'Tab')
  assert.equal(state().enabled, true)
  assert.equal(state().opened, true)
  await open('Saved network')
  await key('-M', 'ctrl', '-s', '50', '-k', 'Delete', '-m', 'ctrl')
  await delay(100)
  assert.equal(state().confirmation, true)
  await key('-k', 'Escape')
  await delay(150)
  assert.ok(state().opened && !state().confirmation)
  await key('Saved network')
  await key('-M', 'ctrl', '-s', '50', '-k', 'Delete', '-m', 'ctrl')
  await delay(100)
  await key('-k', 'Tab', '-k', 'Return')
  assert.deepEqual(state().calls.at(-1), { verb: 'forget', ssid: 'Saved network' })
  assert.equal(state().opened, true)
  ipc('loading')
  assert.equal(state().loading, true)
  await key('-k', 'Escape')
  assert.equal(state().opened, false)
  assert.ok(!/TypeError|ReferenceError|Cannot specify|Failed to load configuration/.test(log), log)
  console.log(JSON.stringify({geometry, checks:'disconnect, saved/open connections, masked password, error/retry/success, prompt cancellation, toggle, forget confirmation and loading; fake backend only'}, null, 2))
} finally {
  if (child && child.exitCode === null) {
    child.kill('SIGTERM')
    await new Promise(resolve => child.once('exit', resolve))
  }
  fs.rmSync(temp, { recursive: true, force: true })
}
