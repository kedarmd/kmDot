#!/usr/bin/env node
// Isolated Bluetooth presentation check; no native BlueZ service is loaded.
import assert from 'node:assert/strict'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { execFileSync, spawn } from 'node:child_process'
import { setTimeout as delay } from 'node:timers/promises'

const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..')
const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'kmdot-bluetooth-view-'))
const shell = path.join(temp, 'shell.qml')
let child, log = ''
const ipc = (method, ...args) => execFileSync('qs', ['ipc', '-p', shell, 'call', '--', 'fixture', method, ...args], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim()
const state = () => JSON.parse(ipc('state'))
async function key(...args) {
  assert.equal(state().focused, true)
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
  fs.writeFileSync(path.join(temp, 'BluetoothStore.qml'), `pragma Singleton
import QtQuick
QtObject {
  property var adapter: ({})
  property bool enabled: true
  property bool discovering: false
  property string errorText: ""
  property string busyPath: ""
  property string busyAction: ""
  property var calls: []
  property var devices: sample()
  function sample() {
    var rows=[
      {path:"/fixture/headphones",name:"Headphones",connected:true,paired:true,pairing:false,icon:"\\uf025",batteryAvailable:true,battery:73,device:{}},
      {path:"/fixture/keyboard",name:"Keyboard",connected:false,paired:true,pairing:false,icon:"\\uf11c",batteryAvailable:false,device:{}},
      {path:"/fixture/phone",name:"New phone",connected:false,paired:false,pairing:false,icon:"\\uf10b",batteryAvailable:false,device:{}}
    ]
    for(var i=1;i<=10;i++) rows.push({path:"/fixture/nearby"+i,name:"Nearby device "+i,connected:false,paired:false,pairing:false,icon:"\\uf293",batteryAvailable:false,device:{}})
    return rows
  }
  function refresh() {}
  function startDiscovery() { if(enabled) discovering=true }
  function stopDiscovery() { discovering=false }
  function setEnabled(on) { if(adapter) enabled=on; if(!enabled) discovering=false }
  function activate(entry) {
    var verb=entry.connected ? "disconnect" : entry.paired ? "connect" : "pair"
    calls=calls.concat([{verb:verb,path:entry.path}]);busyPath=entry.path;busyAction=verb;errorText=""
  }
  function fail() { errorText="Pairing failed: authentication was cancelled. Please try again with the device in pairing mode.";busyPath="";busyAction="" }
  function paired() { devices=devices.map(function(d){return d.path===busyPath ? Object.assign({},d,{paired:true}) : d});busyAction="connect" }
  function connected() { devices=devices.map(function(d){return d.path===busyPath ? Object.assign({},d,{connected:true}) : d});busyPath="";busyAction="" }
  function forget(path) { calls=calls.concat([{verb:"forget",path:path}]);devices=devices.filter(function(d){return d.path!==path}) }
  function emptyScan() { devices=[];discovering=true }
  function noAdapter() { adapter=null;enabled=false;devices=[];discovering=false }
}`)
  fs.writeFileSync(shell, `import QtQuick
import Quickshell
import Quickshell.Io
import "menu"
Scope {
  id: fixture
  property var activeLauncher: null
  property var confirmPopup: confirmation
  function closeAllExcept(except) { if(except!==picker)picker.closeLauncher();if(except!==confirmation)confirmation.close() }
  BluetoothLauncher { id: picker; scope: fixture; sockName: "bluetooth-fixture-${process.pid}" }
  ConfirmPopup { id: confirmation; scope: fixture }
  function find(name,item) { if(item.objectName===name)return item;for(var c of item.children||[]){var f=find(name,c);if(f)return f}return null }
  IpcHandler {
    target: "fixture"
    function open(): void { picker.openLauncher() }
    function fail(): void { BluetoothStore.fail() }
    function paired(): void { BluetoothStore.paired() }
    function connected(): void { BluetoothStore.connected() }
    function emptyScan(): void { BluetoothStore.emptyScan() }
    function noAdapter(): void { BluetoothStore.noAdapter() }
    function clickToggle(): void { find("castLauncherHeaderAction",picker.viewList.parent.parent).clicked() }
    function state(): string {
      var list=picker.viewList,card=list.parent.parent,origin=card.mapToGlobal(0,0)
      var actions=find("castLauncherFooterActions",card),context=find("castLauncherFooterContext",card)
      var error=find("castLauncherListError",card)
      return JSON.stringify({opened:picker.opened,focused:confirmation.opened ? confirmation.focusItem.activeFocus : picker.viewInput.activeFocus,
        selected:picker.selectedItem ? picker.selectedItem.label:"",subtitle:picker.selectedItem ? picker.selectedItem.subtitle:"",count:picker.resultCount,
        primary:picker.primaryActionText,loading:picker.loading,empty:picker.emptyText,error:picker.listErrorText,errorVisible:error.visible,
        errorFits:!error.visible || (list.parent.y+list.y+list.height<=error.y-8 && error.paintedWidth<=error.width+1),
        enabled:BluetoothStore.enabled,discovering:BluetoothStore.discovering,confirmation:confirmation.opened,calls:BluetoothStore.calls,
        headerAction:find("castLauncherHeaderAction",card).text,footerFits:actions.x>=context.x+context.width+16,
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
  assert.ok(geometry.subtitle.includes('Battery 73%'))
  assert.equal(geometry.primary, 'Disconnect')
  assert.equal(geometry.headerAction, 'Bluetooth on')
  capture('kmdot-bluetooth-list.png')
  await key('-k', 'Return')
  assert.deepEqual(state().calls.at(-1), { verb: 'disconnect', path: '/fixture/headphones' })
  assert.equal(state().opened, false)
  assert.equal(state().discovering, false)
  await open('Keyboard')
  assert.equal(state().primary, 'Connect')
  await key('-k', 'Return')
  assert.deepEqual(state().calls.at(-1), { verb: 'connect', path: '/fixture/keyboard' })
  await open('New phone')
  assert.equal(state().primary, 'Pair')
  await key('-k', 'Return')
  assert.equal(state().opened, true)
  assert.equal(state().subtitle, 'Pairing…')
  ipc('fail')
  await delay(100)
  assert.ok(state().errorVisible && state().errorFits)
  capture('kmdot-bluetooth-error.png')
  await key('-k', 'Return')
  assert.equal(state().errorVisible, false)
  ipc('paired')
  assert.equal(state().subtitle, 'Connecting…')
  ipc('connected')
  assert.equal(state().primary, 'Disconnect')
  assert.equal(state().subtitle, 'Connected')
  ipc('clickToggle')
  assert.equal(state().enabled, false)
  assert.equal(state().count, 0)
  assert.equal(state().empty, 'Bluetooth is turned off')
  await key('-k', 'Tab')
  assert.equal(state().enabled, true)
  assert.equal(state().opened, true)
  await open('Keyboard')
  await key('-M', 'ctrl', '-s', '50', '-k', 'Delete', '-m', 'ctrl')
  await delay(100)
  assert.equal(state().confirmation, true)
  await key('-k', 'Escape')
  await delay(150)
  assert.ok(state().opened && !state().confirmation)
  await key('Keyboard')
  await key('-M', 'ctrl', '-s', '50', '-k', 'Delete', '-m', 'ctrl')
  await delay(100)
  await key('-k', 'Tab', '-k', 'Return')
  assert.deepEqual(state().calls.at(-1), { verb: 'forget', path: '/fixture/keyboard' })
  assert.equal(state().opened, true)
  ipc('emptyScan')
  assert.equal(state().loading, true)
  ipc('noAdapter')
  assert.equal(state().empty, 'No Bluetooth adapter')
  await key('-k', 'Escape')
  assert.equal(state().opened, false)
  assert.ok(!/TypeError|ReferenceError|Cannot specify|Failed to load configuration/.test(log), log)
  console.log(JSON.stringify({geometry, checks:'battery, disconnect/connect, pairing progress/error, radio toggle, Forget cancellation/confirmation, discovery lifecycle and no-adapter state; fake backend only'}, null, 2))
} finally {
  if (child && child.exitCode === null) {
    child.kill('SIGTERM')
    await new Promise(resolve => child.once('exit', resolve))
  }
  fs.rmSync(temp, { recursive: true, force: true })
}
