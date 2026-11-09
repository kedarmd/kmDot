import { View, div } from "gpui-kit";
import { home, panes, run, spaces } from "herdr";

// A zero-width block in the personal kmDot layout keeps this reactive view
// alive without changing the native tab bar or running shell processes.
export default class TabTitles extends View {
  init() {
    this.lastPane = JSON.parse(localStorage.getItem("lastPane") ?? "{}");
    this.pending = new Map();
  }

  render() {
    const allPanes = panes();
    const liveTabs = new Set();
    let changed = false;
    for (const space of spaces()) {
      for (const [position, tab] of space.tabs.entries()) {
        liveTabs.add(tab.id);
        const terminals = allPanes.filter(p => p.tab === tab.id && p.terminal);
        const pane = terminals.find(p => p.focused)
          ?? terminals.find(p => p.pane === this.lastPane[tab.id])
          ?? terminals[0];
        if (pane && this.lastPane[tab.id] !== pane.pane) {
          this.lastPane[tab.id] = pane.pane;
          changed = true;
        }
        if (!pane?.cwd) continue;
        const path = pane.cwd.replace(/\\/g, "/").replace(/\/+$/, "") || "/";
        const directory = !space.machine && path === home() ? "~"
          : path.split("/").pop() || "/";
        const name = `${position + 1}. ${directory}`;
        if (tab.name === name) {
          this.pending.delete(tab.id);
          continue;
        }
        // A queued rename itself re-renders the app. Suppress duplicates until
        // it lands, but allow retry on a later update if a machine was offline.
        const pending = this.pending.get(tab.id);
        if (pending?.name === name && Date.now() - pending.at < 2000) continue;
        this.pending.set(tab.id, {name, at: Date.now()});
        run("tab.rename", {id: tab.id, name});
      }
    }
    for (const id of Object.keys(this.lastPane)) {
      if (!liveTabs.has(id)) {
        delete this.lastPane[id];
        this.pending.delete(id);
        changed = true;
      }
    }
    if (changed) localStorage.setItem("lastPane", JSON.stringify(this.lastPane));
    return div();
  }
}
