const test = require("node:test")
const assert = require("node:assert/strict")
const Paths = require("../../config/quickshell/launcher/plugin/core/Paths.js")

const envOf = (vars) => (name) => vars[name] || ""

test("defaults follow the XDG base directory spec", () => {
  const p = Paths.resolve(envOf({ HOME: "/home/u", XDG_RUNTIME_DIR: "/run/user/1000" }))
  assert.equal(p.config, "/home/u/.config/kmdot-launcher")
  assert.equal(p.configFile, "/home/u/.config/kmdot-launcher/config.json")
  assert.equal(p.db, "/home/u/.local/share/kmdot-launcher/db")
  assert.equal(p.extensions, "/home/u/.local/share/kmdot-launcher/extensions")
  assert.equal(p.cache, "/home/u/.cache/kmdot-launcher")
  assert.equal(p.logs, "/home/u/.local/state/kmdot-launcher/logs")
  assert.equal(p.runtime, "/run/user/1000/kmdot-launcher")
  assert.equal(p.scriptCommands, "/home/u/.config/kmdot-launcher/script-commands")
})

test("absolute XDG overrides win, relative ones are ignored", () => {
  const p = Paths.resolve(envOf({
    HOME: "/home/u/",
    XDG_CONFIG_HOME: "/cfg/",
    XDG_DATA_HOME: "relative/data",
    XDG_STATE_HOME: "/st"
  }))
  assert.equal(p.config, "/cfg/kmdot-launcher")
  assert.equal(p.data, "/home/u/.local/share/kmdot-launcher")
  assert.equal(p.state, "/st/kmdot-launcher")
})

test("missing HOME is an error", () => {
  assert.throws(() => Paths.resolve(envOf({})), /HOME is not set/)
})

test("startup creates the persistent dirs and the runtime dir", () => {
  const p = Paths.resolve(envOf({ HOME: "/h", XDG_RUNTIME_DIR: "/r" }))
  assert.deepEqual(Paths.directoriesToCreate(p), [
    "/h/.config/kmdot-launcher", "/h/.local/share/kmdot-launcher/db", "/h/.cache/kmdot-launcher",
    "/h/.local/state/kmdot-launcher/logs", "/h/.local/state/kmdot-launcher/backups", "/r/kmdot-launcher"
  ])
})
