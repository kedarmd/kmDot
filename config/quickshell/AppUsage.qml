pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

// App-launcher usage store: { appId -> { count, lastUsed } } persisted to
// ~/.config/kmdot/app-usage.json so the learning survives quickshell restarts
// (theme switches restart quickshell) and cache cleaners. Consumed only by
// AppLauncher.qml: the FREQUENT block in the empty-query view and a mild
// usage boost when searching. Launches made outside the launcher (e.g. from
// a terminal) are intentionally NOT counted.
Singleton {
  id: root

  // --- tuning ---
  // Recency decay: a heavy-but-abandoned app fades out over ~week scales.
  readonly property real recencyHalfLifeDays: 10
  // Frequent-block gates: must be used at least twice AND still "warm".
  readonly property int minCount: 2
  readonly property real minFrecency: 0.35
  readonly property int maxTop: 6
  // Search boost: multiplier 1 + searchBoostMax * usageFactor(U). Sized so a
  // boosted substring match (<= 50000 base) can never outrank an exact match.
  readonly property real searchBoostMax: 0.35
  // U that maps to a full boost (a couple of uses within the last day).
  readonly property real searchBoostNorm: 2.5
  // Keep the file bounded; evict the coldest entries first.
  readonly property int maxEntries: 96

  readonly property string storePath: {
    const cfg = Quickshell.env("XDG_CONFIG_HOME")
    const dir = cfg ? cfg : (Quickshell.env("HOME") + "/.config")
    return dir + "/kmdot/app-usage.json"
  }

  // appId -> { count, lastUsed (epoch ms) }
  property var usage: ({})
  // FileView load completion; operations landing before load are queued.
  property bool ready: false
  property var pending: []

  FileView {
    id: usageFile
    path: root.storePath
    watchChanges: false

    onLoadFailed: {
      root.ready = true
      root.flushPending()
      root.save()
    }
    onLoaded: {
      if (root.ready) return
      const content = usageFile.text()
      const obj = content ? JSON.parse(content) : {}
      const out = {}
      for (const id in obj) {
        const v = obj[id]
        if (!v || typeof v !== "object" || typeof v.count !== "number") continue
        if (v.count <= 0 || !(v.lastUsed > 0)) continue
        out[id] = { count: Math.round(v.count), lastUsed: v.lastUsed }
      }
      root.usage = out
      root.ready = true
      root.flushPending()
    }
  }

  function flushPending() {
    const ops = root.pending
    root.pending = []
    for (const i in ops) {
      const op = ops[i]
      if (op.op === "record") root.record(op.id)
      else if (op.op === "prune") root.prune(op.ids)
    }
  }

  function save() {
    usageFile.setText(JSON.stringify(root.usage))
  }

  // Record one launch of the app. Safe to call before the store is loaded
  // (queued and applied after load instead of racing it).
  function record(id) {
    if (id === undefined || id === null || id === "") return
    if (!root.ready) {
      root.pending.push({ op: "record", id })
      return
    }
    const cur = root.usage[id] || { count: 0, lastUsed: 0 }
    const out = Object.assign({}, root.usage)
    out[id] = { count: cur.count + 1, lastUsed: Date.now() }
    root.usage = root.enforceCap(out)
    root.save()
  }

  // Drop usage entries whose app no longer exists (DesktopEntries refresh).
  function prune(validIds) {
    if (!root.ready) {
      root.pending.push({ op: "prune", ids: validIds })
      return
    }
    const has = {}
    for (const i in validIds) has[validIds[i]] = true
    let dirty = false
    const out = {}
    for (const id in root.usage) {
      if (has[id]) out[id] = root.usage[id]
      else dirty = true
    }
    if (!dirty) return
    root.usage = root.enforceCap(out)
    root.save()
  }

  // Keep at most maxEntries, evicting the coldest (lowest frecency) first.
  function enforceCap(map) {
    const ids = Object.keys(map)
    if (ids.length <= root.maxEntries) return map
    const now = Date.now()
    ids.sort((a, b) => root.frecency(b, now) - root.frecency(a, now))
    const out = {}
    for (let i = 0; i < root.maxEntries; i++) out[ids[i]] = map[ids[i]]
    return out
  }

  // Frequency + recency score for an app (0 when unused/unfrequentable):
  // ln(1 + count) * e^(-ageDays / halfLife). Requires no count gating —
  // callers decide eligibility (isFrequent) vs raw factor (searchBoost).
  function frecency(id, now) {
    const v = root.usage[id]
    if (!v || v.count <= 0 || !(v.lastUsed > 0)) return 0
    const ageDays = Math.max(0, ((now || Date.now()) - v.lastUsed) / 86400000)
    return Math.log(1 + v.count) * Math.exp(-ageDays / root.recencyHalfLifeDays)
  }

  // Candidate for the empty-query FREQUENT block.
  function isFrequent(id, now) {
    const v = root.usage[id]
    if (!v || v.count < root.minCount) return false
    return root.frecency(id, now) >= root.minFrecency
  }

  // Multiplier for search scores; usage raises a match without letting it
  // beat stronger text matches of unused apps.
  function searchBoost(id) {
    return 1 + root.searchBoostMax * root.usageFactor(id)
  }

  // Normalized 0..1 how "in use" an app is right now.
  function usageFactor(id) {
    return Math.min(1, root.frecency(id, Date.now()) / root.searchBoostNorm)
  }
}
