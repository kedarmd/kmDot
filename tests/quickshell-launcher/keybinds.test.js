const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')
const { execFileSync } = require('node:child_process')

const model = import('../../config/quickshell/scripts/keybinds.mjs')
const live = (key, modmask = 0, extra = {}) => ({ key, modmask, dispatcher: '__lua', arg: '1', ...extra })

test('the collector emits JSON through a symlinked configuration path', t => {
  const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'kmdot-keybinds-cli-'))
  t.after(() => fs.rmSync(temp, { recursive: true, force: true }))
  const bin = path.join(temp, 'bin')
  fs.mkdirSync(bin)
  fs.writeFileSync(path.join(bin, 'hyprctl'), '#!/bin/bash\nprintf \'%s\' \'[{"key":"F9","modmask":0,"description":"Runtime via symlink"}]\'\n', { mode: 0o755 })
  fs.writeFileSync(path.join(bin, 'lua'), '#!/bin/bash\nexit 0\n', { mode: 0o755 })
  const alias = path.join(temp, 'keybinds.mjs')
  fs.symlinkSync(path.resolve(__dirname, '../../config/quickshell/scripts/keybinds.mjs'), alias)
  const stdout = execFileSync(process.execPath, [alias], {
    env: { ...process.env, HOME: temp, PATH: bin + ':' + process.env.PATH }, encoding: 'utf8'
  })
  assert.ok(stdout.trim(), 'Symlink entry must execute the collector rather than return empty stdout')
  const result = JSON.parse(stdout)
  assert.equal(result.ok, true)
  assert.equal(result.items[0].label, 'Runtime via symlink')
})

test('the live registry is the complete inventory; source-only bindings never create rows', async () => {
  const { buildBindings } = await model
  const source = 'SUPER + T\tTheme switcher\tkmdot-theme\nSUPER + Y\tNot active\tunregistered\n'
  const rows = buildBindings([live('T', 64), live('F9', 0)], source)
  assert.equal(rows.length, 2)
  assert.equal(rows[0].label, 'Theme switcher')
  assert.equal(rows[0].meta, 'Super T')
  assert.equal(rows[1].label, 'Custom shortcut')
  assert.equal(rows[1].descriptionSource, 'none')
  assert.deepEqual(buildBindings([], source), [])
  assert.ok(!rows.some(row => row.label === 'Not active'))
})

test('modifier order, case, arrow names, code bindings and mouse bindings are normalised', async () => {
  const { buildBindings, sourceChord } = await model
  assert.equal(sourceChord('shift + super + p'), sourceChord('SUPER + SHIFT + P'))
  const rows = buildBindings([
    live('p', 65), live('left', 64), live('', 4, { keycode: 25 }), live('mouse:272', 64, { mouse: false })
  ], 'SHIFT + SUPER + P\tCustom app\t\nSUPER + LEFT\tFocus left\t\nCTRL + code:25\tCode action\t\nSUPER + mouse:272\tDrag window\t\n')
  assert.deepEqual(rows.map(row => row.label), ['Custom app', 'Focus left', 'Code action', 'Drag window'])
  assert.equal(rows[1].meta, 'Super ←')
  assert.equal(rows[1].rawKeys, 'Super left')
  assert.equal(rows[2].meta, 'Ctrl code:25')
  assert.match(rows[3].subtitle, /Mouse/)
})

test('native descriptions win; ambiguous chords retain every row without guessed config labels', async () => {
  const { buildBindings } = await model
  const rows = buildBindings([
    live('T', 64, { description: 'Live description' }),
    live('R', 64), live('R', 64, { release: true }),
    live('G', 64, { submap: 'resize' })
  ], 'SUPER + T\tOld description\t\nSUPER + R\tPress only\t\nSUPER + G\tRoot-only description\t\n')
  assert.equal(rows[0].label, 'Live description')
  assert.equal(rows[0].descriptionSource, 'hyprland')
  assert.equal(rows[1].label, 'Custom shortcut')
  assert.equal(rows[2].label, 'Custom shortcut')
  assert.match(rows[2].subtitle, /On release/)
  assert.equal(rows[3].label, 'Custom shortcut')
  assert.match(rows[3].subtitle, /Submap: resize/)
  assert.equal(new Set(rows.map(row => row.id)).size, rows.length)
})

test('duplicate source descriptions are not guessed and runtime-only flags are retained', async () => {
  const { buildBindings } = await model
  const rows = buildBindings([live('F1', 0, { repeat: true, locked: true, longPress: true })],
    'F1\tFirst\t\nF1\tSecond\t\n')
  assert.equal(rows[0].descriptionSource, 'none')
  assert.match(rows[0].subtitle, /Repeats/)
  assert.match(rows[0].subtitle, /Long press/)
  assert.match(rows[0].subtitle, /While locked/)
})

test('identities survive unrelated insertion and malformed runtime data cannot produce fallback bindings', async () => {
  const { buildBindings } = await model
  const before = buildBindings([live('T', 64)])
  const after = buildBindings([live('F1'), live('T', 64)])
  assert.equal(before[0].id, after[1].id)
  assert.throws(() => buildBindings({}), /invalid binding list/)
  assert.throws(() => buildBindings([null]), /invalid binding list/)
})
