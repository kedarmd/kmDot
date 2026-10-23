#!/usr/bin/env node
// Live backend checks plus reversible overlay show/hide and handoff.
import assert from 'node:assert/strict'
import { execFileSync } from 'node:child_process'
import { setTimeout as delay } from 'node:timers/promises'

const shell = `${process.env.HOME}/.config/quickshell/shell.qml`
const ipc = (...args) => execFileSync('qs', ['ipc', '-p', shell, 'call', '--', 'kmdot-launcher', ...args], { encoding: 'utf8' }).trim()
function rpc(method, data = {}) {
  const result = JSON.parse(ipc('call', method, JSON.stringify(data)))
  assert.ok(result.ok, JSON.stringify(result))
  return result.data
}
const layers = () => Object.values(JSON.parse(execFileSync('hyprctl', ['layers', '-j'], { encoding: 'utf8' })))
  .flatMap(screen => screen.levels['3'] || [])
const originalOpen = ipc('isOpen') === 'true'
const originalFilter = ipc('filter')
const toggle = name => execFileSync(`${process.env.HOME}/.config/kmdot/quickshell/scripts/toggle.sh`, [name], { encoding: 'utf8' })

try {
  const info = rpc('system.info')
  assert.ok(info.ready && info.theme.loaded && info.candidates > 0)
  assert.equal(rpc('system.getPaths').config, `${process.env.XDG_CONFIG_HOME || process.env.HOME + '/.config'}/kmdot-launcher`)
  assert.equal(rpc('system.healthDatabase').readOnly, false)
  assert.ok(rpc('calculator.calculate', { query: '5 ft to cm' }))
  const apps = rpc('rootSearch.search', { query: '', filter: 'applications' }).flatMap(s => s.rows)
  assert.ok(apps.length > 0 && apps.every(r => r.type === 'application'))
  const wifi = rpc('rootSearch.search', { query: 'wifi' }).flatMap(s => s.rows)
  assert.ok(wifi.some(r => r.id === 'kmdot:wifi'))
  assert.ok(!wifi.some(r => r.id === 'kmdot:menu'))
  const unknown = JSON.parse(ipc('call', 'unknown.method', '{}'))
  assert.equal(unknown.ok, false)
  console.log(`Backend ready: ${info.candidates} apps/commands; calculator, theme, paths and stores OK.`)

  ipc('hide')
  for (let i = 0; i < 3; i++) {
    assert.equal(ipc('show'), 'shown')
    await delay(300)
    assert.equal(layers().filter(l => l.namespace === 'kmdot-launcher').length, 1)
    assert.equal(ipc('hide'), 'hidden')
    await delay(100)
    assert.equal(layers().filter(l => l.namespace === 'kmdot-launcher').length, 0)
  }
  // Both socket entry points share a surface; changing mode keeps it open,
  // while repeating the same mode toggles it closed.
  toggle('kmdot-launcher')
  await delay(300)
  assert.equal(ipc('filter'), 'applications')
  assert.equal(ipc('isOpen'), 'true')
  assert.equal(layers().length, 1)
  toggle('kmdot-kmdot')
  await delay(300)
  assert.equal(ipc('filter'), 'all')
  assert.equal(ipc('isOpen'), 'true')
  assert.equal(layers().length, 1)
  toggle('kmdot-kmdot')
  await delay(100)
  assert.equal(ipc('isOpen'), 'false')
  ipc('show')
  const result = JSON.parse(ipc('run', 'kmdot:apps'))
  assert.ok(result.ok)
  assert.equal(result.data.filter, 'applications')
  assert.equal(ipc('isOpen'), 'true')
  assert.equal(ipc('filter'), 'applications')
  assert.equal(layers().length, 1)

  // A separate existing menu still hands off through the shell coordinator.
  assert.ok(JSON.parse(ipc('run', 'kmdot:themes')).ok)
  await delay(500)
  assert.equal(ipc('isOpen'), 'false')
  assert.equal(layers().filter(l => l.namespace === 'kmdot-launcher').length, 0)
  assert.equal(layers().length, 1)
  ipc('show')
  await delay(300)
  assert.equal(layers().length, 1)
  assert.equal(layers()[0].namespace, 'kmdot-launcher')
  console.log('Show/hide, both filter entry points, in-place Applications action and theme-menu handoff passed.')
} finally {
  ipc(originalOpen ? (originalFilter === 'applications' ? 'showApplications' : 'show') : 'hide')
}
