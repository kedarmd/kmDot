#!/usr/bin/env node
// Hyprland owns the inventory; the existing Lua inspector only enriches labels.
import { execFile } from 'node:child_process'
import { promisify } from 'node:util'
import path from 'node:path'
import os from 'node:os'
import { fileURLToPath } from 'node:url'
import { realpathSync } from 'node:fs'

const exec = promisify(execFile)
// Modifier names and key labels describe input symbols, never binding entries.
const modifiers = [
  { bit: 64, label: 'Super', names: ['SUPER', 'MOD4', 'WIN', 'LOGO'] },
  { bit: 4, label: 'Ctrl', names: ['CTRL', 'CONTROL'] },
  { bit: 8, label: 'Alt', names: ['ALT', 'MOD1'] },
  { bit: 1, label: 'Shift', names: ['SHIFT'] },
  { bit: 2, label: 'Caps', names: ['CAPS', 'CAPSLOCK', 'LOCK'] },
  { bit: 16, label: 'Mod2', names: ['MOD2'] },
  { bit: 32, label: 'Mod3', names: ['MOD3'] },
  { bit: 128, label: 'Mod5', names: ['MOD5', 'ALTGR'] }
]
const keyAliases = { ENTER: 'RETURN', ESC: 'ESCAPE', ' ': 'SPACE' }
const keyLabels = { RETURN: 'Enter', ESCAPE: 'Esc', SPACE: 'Space', LEFT: '←', RIGHT: '→', UP: '↑', DOWN: '↓', TAB: 'Tab', BACKSPACE: 'Backspace', DELETE: 'Del', PRINT: 'Print' }
const clean = value => String(value ?? '').replace(/\s+/g, ' ').trim()
const keyName = value => keyAliases[String(value).toUpperCase()] || String(value).toUpperCase()

export function sourceChord(text) {
  const parts = clean(text).split(/\s*\+\s*/)
  const key = parts.pop()
  if (!key) return null
  let mask = 0
  for (const part of parts) {
    const modifier = modifiers.find(m => m.names.includes(part.toUpperCase()))
    if (!modifier) return null
    mask |= modifier.bit
  }
  return `${mask}:${keyName(key)}`
}

function liveChord(binding) {
  const key = Number(binding.keycode) > 0 ? `CODE:${binding.keycode}` : keyName(binding.key || '')
  return `${Number(binding.modmask) || 0}:${key}`
}

export function sourceDescriptions(text) {
  const groups = new Map()
  for (const line of String(text).split('\n')) {
    const first = line.indexOf('\t'), last = line.lastIndexOf('\t')
    if (first < 0 || last <= first) continue
    const chord = sourceChord(line.slice(0, first))
    if (!chord) continue
    const entries = groups.get(chord) || []
    entries.push(clean(line.slice(first + 1, last)))
    groups.set(chord, entries)
  }
  return groups
}

function displayChord(binding, pretty = true) {
  const mask = Number(binding.modmask) || 0
  const labels = modifiers.filter(m => mask & m.bit).map(m => m.label)
  const key = keyName(binding.key || '')
  labels.push(Number(binding.keycode) > 0 ? `code:${binding.keycode}`
    : (pretty && keyLabels[key]) || (key.length === 1 ? key : clean(binding.key))
      || (binding.catch_all ? 'Any-key' : 'Unknown-key'))
  return labels.join(' ')
}

export function buildBindings(live, descriptions = '') {
  if (!Array.isArray(live) || live.some(b => !b || typeof b !== 'object' || Array.isArray(b))) {
    throw new Error('Hyprland returned an invalid binding list')
  }
  const source = sourceDescriptions(descriptions)
  const counts = new Map()
  for (const binding of live) {
    const chord = liveChord(binding)
    counts.set(chord, (counts.get(chord) || 0) + 1)
  }
  const identities = new Map()
  return live.map(binding => {
    const chord = liveChord(binding)
    const candidates = source.get(chord) || []
    // Do not assign comments to ambiguous submap/release/duplicate chords.
    const comment = !clean(binding.submap) && counts.get(chord) === 1 && candidates.length === 1 ? candidates[0] : ''
    const native = clean(binding.description)
    const description = native || comment
    const details = []
    if (!description) details.push('No description available')
    if (clean(binding.submap)) details.push(`Submap: ${clean(binding.submap)}`)
    if (binding.release === true) details.push('On release')
    if (binding.repeat === true) details.push('Repeats')
    if (binding.longPress === true) details.push('Long press')
    if (binding.locked === true) details.push('While locked')
    const mouse = /^mouse:/i.test(binding.key || '') || binding.mouse === true
    if (mouse) details.push('Mouse')
    const flags = ['release', 'repeat', 'longPress', 'locked', 'non_consuming', 'mouse', 'catch_all'].filter(flag => binding[flag] === true)
    const identity = JSON.stringify([chord, clean(binding.submap), flags])
    const occurrence = identities.get(identity) || 0
    identities.set(identity, occurrence + 1)
    return {
      id: `${identity}:${occurrence}`,
      label: description || 'Custom shortcut',
      subtitle: details.join(' · '),
      meta: displayChord(binding),
      rawKeys: displayChord(binding, false),
      glyph: mouse ? '\uf245' : '\uf11c',
      descriptionSource: native ? 'hyprland' : comment ? 'config' : 'none'
    }
  })
}

export async function snapshot() {
  const hyprland = path.join(os.homedir(), '.config/kmdot/hyprland')
  const options = { encoding: 'utf8', timeout: 3000, maxBuffer: 4 * 1024 * 1024 }
  const [runtime, source] = await Promise.allSettled([
    exec('hyprctl', ['binds', '-j'], options),
    exec('lua', [path.join(hyprland, 'scripts/keybinds.lua'), path.join(hyprland, 'keybinds.lua')], options)
  ])
  if (runtime.status !== 'fulfilled') return { ok: false, items: [], error: 'Unable to read active Hyprland keybindings' }
  try {
    const live = JSON.parse(runtime.value.stdout)
    const items = buildBindings(live, source.status === 'fulfilled' ? source.value.stdout : '')
    return {
      ok: true, items,
      stats: { live: items.length, described: items.filter(i => i.descriptionSource !== 'none').length },
      warning: source.status === 'fulfilled' ? '' : 'Config descriptions unavailable; showing live bindings'
    }
  } catch {
    return { ok: false, items: [], error: 'Hyprland returned an unreadable binding list' }
  }
}

function isEntryPoint() {
  try {
    return !!process.argv[1] && realpathSync(process.argv[1]) === realpathSync(fileURLToPath(import.meta.url))
  } catch { return false }
}

if (isEntryPoint()) {
  process.stdout.write(JSON.stringify(await snapshot()) + '\n')
}
