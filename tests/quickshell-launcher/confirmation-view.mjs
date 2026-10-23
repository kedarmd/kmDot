#!/usr/bin/env node
// Isolated confirmation UI: signal counters replace every destructive caller.
import assert from 'node:assert/strict'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { execFileSync, spawn } from 'node:child_process'
import { setTimeout as delay } from 'node:timers/promises'

const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..')
const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'kmdot-confirmation-view-'))
const shell = path.join(temp, 'shell.qml')
let child, log = ''
const ipc = (method, ...args) => execFileSync('qs', ['ipc', '-p', shell, 'call', '--', 'fixture', method, ...args], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim()
const state = () => JSON.parse(ipc('state'))
async function key(...args) {
  assert.equal(state().focused, true)
  execFileSync('wtype', args)
  await delay(150)
}
async function open(kind) { ipc('show', kind); await delay(250) }

try {
  fs.cpSync(path.join(repo, 'config/quickshell'), temp, { recursive: true })
  fs.writeFileSync(path.join(temp, 'Colors.qml'), execFileSync(path.join(repo, 'theme-switcher/render-quickshell.sh'), [path.join(repo, 'themes/everforest/quickshell.conf')]))
  fs.writeFileSync(shell, `import QtQuick
import Quickshell
import Quickshell.Io
import "menu"
Scope {
  id: fixture
  property int confirmedCount: 0
  property int cancelledCount: 0
  ConfirmPopup {
    id: popup
    onConfirmed: fixture.confirmedCount++
    onCancelled: fixture.cancelledCount++
  }
  function find(name, item) {
    if (item.objectName === name) return item
    for (var child of item.children || []) { var found = find(name, child); if (found) return found }
    return null
  }
  IpcHandler {
    target: "fixture"
    function show(kind: string): void {
      if (kind === "handy") popup.ask("Delete recording?", "October 24, 12:30 AM", {
        showKeyboardHints:false,titleGlyph:"\\uf1f8",titleGlyphColor:Colors.text,
        supportingText:"This deletes the recording and its transcription. This action cannot be undone.",
        confirmText:"Delete",cancelText:"Keep recording",confirmFill:Colors.error,confirmTextColor:Colors.surface
      })
      else if (kind === "bluetooth") popup.ask("Forget Bluetooth device", "Remove 'Example headphones' and disconnect it? You will need to pair it again to use it.")
      else popup.ask("Forget Wi-Fi network", "Forget '<b>Example network with a long name & literal markup</b>'? You will need to re-enter the password to connect again.")
    }
    function close(): void { popup.close() }
    function clickConfirm(): void { find("confirmationAccept", popup.contentItem).clicked() }
    function clickCancel(): void { find("confirmationCancel", popup.contentItem).clicked() }
    function state(): string {
      var card = find("popupCard", popup.contentItem)
      var heading = find("confirmationHeading", popup.contentItem)
      var message = find("confirmationMessage", popup.contentItem)
      var support = find("confirmationSupportingText", popup.contentItem)
      var cancel = find("confirmationCancel", popup.contentItem)
      var accept = find("confirmationAccept", popup.contentItem)
      return JSON.stringify({opened:popup.opened,focused:popup.focusItem.activeFocus,
        selected:popup.selectedAction,confirmed:fixture.confirmedCount,cancelled:fixture.cancelledCount,
        card:{width:card.width,height:card.height,radius:card.radius,border:card.border.width,
          globalX:popup.screen.x+card.x,globalY:popup.screen.y+card.y},
        headingHeight:heading.height,messageFits:message.paintedWidth<=message.width+1,
        plainText:message.textFormat===Text.PlainText,supportVisible:support.visible,
        cancel:{label:cancel.text,width:cancel.width,height:cancel.height,radius:cancel.radius,font:cancel.fontFamily},
        accept:{label:accept.text,width:accept.width,height:accept.height,radius:accept.radius},
        buttonsFit:cancel.width+accept.width+8<=cancel.parent.parent.width})
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
  await open('wifi')
  const wifi = state()
  assert.equal(wifi.card.width, 424)
  assert.equal(wifi.card.radius, 20)
  assert.equal(wifi.card.border, 1)
  assert.ok(wifi.messageFits && wifi.plainText && wifi.buttonsFit)
  assert.equal(wifi.cancel.height, 34)
  assert.equal(wifi.cancel.radius, 8)
  assert.equal(wifi.selected, 0)
  const capture = (name, s) => execFileSync('grim', ['-g', `${s.card.globalX},${s.card.globalY} ${s.card.width}x${s.card.height}`, path.join(os.tmpdir(), name)])
  capture('kmdot-confirmation-wifi.png', wifi)
  await key('-k', 'Return')
  assert.equal(state().confirmed, 0)
  assert.equal(state().cancelled, 1)
  await open('bluetooth')
  await key('-k', 'Tab')
  assert.equal(state().selected, 1)
  await key('-k', 'Return')
  assert.equal(state().confirmed, 1)
  assert.equal(state().opened, false)
  await open('handy')
  const handy = state()
  assert.ok(handy.supportVisible && handy.buttonsFit)
  assert.equal(handy.cancel.label, 'Keep recording')
  assert.equal(handy.accept.label, 'Delete')
  capture('kmdot-confirmation-handy.png', handy)
  await key('-k', 'Escape')
  assert.equal(state().cancelled, 2)
  await open('wifi')
  ipc('close')
  ipc('close')
  assert.equal(state().cancelled, 3, 'Backdrop/programmatic close cancels once')
  await open('handy')
  ipc('clickConfirm')
  ipc('clickConfirm')
  assert.equal(state().confirmed, 2, 'Repeated clicks cannot confirm twice')
  await open('wifi')
  ipc('clickCancel')
  assert.equal(state().cancelled, 4)
  assert.ok(!/TypeError|ReferenceError|Cannot specify|Failed to load configuration/.test(log), log)
  console.log(JSON.stringify({wifi, handy, checks:'default cancellation, explicit confirmation, Escape, dismissal, mouse actions and once-only signals'}, null, 2))
} finally {
  if (child && child.exitCode === null) {
    child.kill('SIGTERM')
    await new Promise(resolve => child.once('exit', resolve))
  }
  fs.rmSync(temp, { recursive: true, force: true })
}
