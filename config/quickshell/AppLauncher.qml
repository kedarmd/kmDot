import QtQuick
import Quickshell
import "components"
import qs

LauncherBase {
  id: root

  sockName: "kmdot-launcher"
  title: "Search applications"
  headerTitle: "Applications"
  // Section headers replace the single label in the empty-query view; search
  // results keep the SUGGESTED label (no sections while a query is typed).
  resultsLabel: root.query.trim() !== "" ? "SUGGESTED" : ""
  sectionRole: root.query.trim() !== "" || root.frequentCount === 0 ? "" : "section"
  cardHeight: root.query.trim() !== "" && root.resultCount === 0 && !root.loading ? 400 : 608
  countNoun: "app"
  footerHint: "\u2191\u2193 navigate \u00b7 \u23ce launch"

  property var apps: []
  // Size of the last-produced FREQUENT block; drives the sectionRole binding.
  property int frequentCount: 0

  function rebuildApps() {
    const vals = DesktopEntries.applications.values
    const out = []
    for (let i = 0; i < vals.length; i++) {
      const e = vals[i]
      if (e.noDisplay) continue
      out.push(e)
    }
    out.sort((a, b) => a.name.localeCompare(b.name))
    AppUsage.prune(out.map(e => e.id))
    root.apps = out
  }

  Component.onCompleted: root.rebuildApps()

  Connections {
    target: DesktopEntries.applications
    function onValuesChanged() { root.rebuildApps() }
  }

  pool: root.apps

  onActivated: function(item) {
    AppUsage.record(item.id)
    item.execute()
  }

  function filterAndSort(items, q) {
    if (q === "") return root.sortFrequentFirst(items)
    const sub = q.toLowerCase()
    const out = []
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
      // Mild usage boost so apps you actually launch win close matches;
      // sized so it can never lift a weaker match over an exact one.
      out.push({ item: e, score: best * AppUsage.searchBoost(e.id) })
    }
    out.sort((a, b) => b.score - a.score || a.item.name.localeCompare(b.item.name))
    return out
  }

  // Empty query: top frecency apps under FREQUENT, everything else
  // alphabetically under ALL APPS. No frequent apps yet → plain list
  // (the launcher hides sections then).
  function sortFrequentFirst(items) {
    const now = Date.now()
    const candidates = []
    for (const e of items) {
      if (!AppUsage.isFrequent(e.id, now)) continue
      candidates.push({ e, u: AppUsage.frecency(e.id, now) })
    }
    candidates.sort((a, b) => b.u - a.u || a.e.name.localeCompare(b.e.name))
    const top = candidates.slice(0, AppUsage.maxTop)

    const chosen = {}
    for (const c of top) chosen[c.e.id] = true
    root.frequentCount = top.length

    const out = []
    for (const c of top) out.push({ item: c.e, score: 0, section: "FREQUENTS" })
    for (const e of items) {
      if (chosen[e.id]) continue
      out.push({ item: e, score: 0, section: "ALL APPS" })
    }
    return out
  }
}
