import QtQuick
import Quickshell
import "components"
import qs

LauncherBase {
  id: root

  sockName: "kmdot-launcher"
  title: "Search applications"
  countNoun: "app"
  footerHint: "\u2191\u2193 navigate \u00b7 \u23ce launch \u00b7 esc close"

  property var apps: (function () {
    const vals = DesktopEntries.applications.values
    const out = []
    for (let i = 0; i < vals.length; i++) {
      const e = vals[i]
      if (e.noDisplay) continue
      out.push(e)
    }
    out.sort((a, b) => a.name.localeCompare(b.name))
    return out
  })()

  pool: root.apps

  onActivated: function(item) {
    item.execute()
  }

  function filterAndSort(items, q) {
    const out = []
    if (!q) {
      for (const e of items) out.push({ item: e, score: 0 })
      return out
    }
    const sub = q.toLowerCase()
    for (const e of items) {
      let best = root.fieldScore(e.name, q)
      const g = root.fieldScore(e.genericName, q)
      if (g >= 0) best = Math.max(best, g - 1000)
      for (const pair of [
        [e.execString, 1500],
        [e.keywords, 1000],
        [e.comment, 500],
        [e.id, 400]
      ]) {
        const idx = root.toStr(pair[0]).toLowerCase().indexOf(sub)
        if (idx >= 0) best = Math.max(best, pair[1] - idx)
      }
      if (best < 0) continue
      out.push({ item: e, score: best })
    }
    out.sort((a, b) => b.score - a.score || a.item.name.localeCompare(b.item.name))
    return out
  }
}
