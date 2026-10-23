const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')
const { spawnSync } = require('node:child_process')

const repo = path.resolve(__dirname, '../..')

function fixture(t) {
  const home = fs.mkdtempSync(path.join(os.tmpdir(), 'kmdot-launcher-sync-'))
  t.after(() => fs.rmSync(home, { recursive: true, force: true }))
  const bin = path.join(home, 'bin')
  fs.mkdirSync(bin)
  fs.writeFileSync(path.join(bin, 'systemctl'), '#!/usr/bin/env bash\nprintf "%s\\n" "$*" >> "$HOME/service-calls"\n', { mode: 0o755 })
  const roots = ['config', 'data', 'cache', 'state'].map(name => path.join(home, name))
  const env = { ...process.env, HOME: home, PATH: bin + ':' + process.env.PATH,
    XDG_CONFIG_HOME: roots[0], XDG_DATA_HOME: roots[1], XDG_CACHE_HOME: roots[2], XDG_STATE_HOME: roots[3],
    WAYLAND_DISPLAY: '' }
  function write(file, text) {
    fs.mkdirSync(path.dirname(file), { recursive: true })
    fs.writeFileSync(file, text)
  }
  function sync() {
    const r = spawnSync('bash', [path.join(repo, 'sync/quickshell.sh'), 'nord'], { env, encoding: 'utf8' })
    assert.equal(r.status, 0, r.stderr)
  }
  return { home, roots, write, sync }
}

test('sync imports legacy data once, excludes the checkout link and retires the owned service', t => {
  const f = fixture(t)
  for (const root of f.roots) f.write(path.join(root, 'kay-cast/nested/preferences.json'), '{"favorite":"app:test"}')
  fs.symlinkSync('/unavailable/upstream/checkout', path.join(f.roots[0], 'kay-cast/runtime'))
  f.write(path.join(f.roots[0], 'systemd/user/kay-cast.service'), '# Managed by kay-cast\n[Service]\n')
  f.sync()
  assert.match(fs.readFileSync(path.join(f.home, 'service-calls'), 'utf8'), /--user disable --now kay-cast.service/)
  for (const root of f.roots) {
    const dest = path.join(root, 'kmdot-launcher/nested/preferences.json')
    assert.equal(fs.readFileSync(dest, 'utf8'), '{"favorite":"app:test"}')
    f.write(dest, 'newer kmDot preference')
  }
  assert.throws(() => fs.lstatSync(path.join(f.roots[0], 'kmdot-launcher/runtime')), { code: 'ENOENT' })
  f.sync()
  for (const root of f.roots) assert.equal(fs.readFileSync(path.join(root, 'kmdot-launcher/nested/preferences.json'), 'utf8'), 'newer kmDot preference')
  assert.equal(fs.readlinkSync(path.join(f.roots[0], 'kay-cast/runtime')), '/unavailable/upstream/checkout')
})

test('fresh installs deploy a self-contained launcher and leave unowned services alone', t => {
  const f = fixture(t)
  f.write(path.join(f.roots[0], 'systemd/user/kay-cast.service'), '# Another owner\n')
  f.sync()
  assert.equal(fs.existsSync(path.join(f.home, 'service-calls')), false)
  const deployed = path.join(f.home, '.config/kmdot/quickshell')
  for (const helper of ['kmdot-launcher-desktop', 'kmdot-launcher-launch']) {
    fs.accessSync(path.join(deployed, 'launcher/bin', helper), fs.constants.X_OK)
  }
  assert.ok(fs.readFileSync(path.join(deployed, 'launcher/plugin/Launcher.qml'), 'utf8').includes('closeAllExcept'))
  assert.ok(fs.readFileSync(path.join(deployed, 'Colors.qml'), 'utf8').includes('property color primary'))
  assert.equal(fs.realpathSync(path.join(f.home, '.config/quickshell')), deployed)
})
