#!/usr/bin/env node
// kmDot herdr plugin event hook — keeps tab labels as
// "<tab number>. <directory>" across tab topology changes.
//
// Closing or re-ordering tabs shifts every later tab's position,
// and no prompt re-renders in the surviving panes, so the fish
// prompt hook (which only fires on cd) leaves the old number
// prefixes stale. This hook runs on tab.created / tab.closed /
// tab.moved and heals the whole session in one pass:
//
//   * "<N>. <name>" labels get their number rewritten to the
//     tab's current position (the name half is kept)
//   * bare-number labels (fresh tabs) get named after the
//     tab's focused pane's directory
//   * anything else — a tab renamed by hand — is left alone
//
// The fish prompt hook (config/fish/config.fish) covers the
// other half: renaming a tab the moment its pane cd's.
//
// Silent no-op on any error — this runs inside herdr's event
// system and must never take the server down with it.

import { execFile } from "node:child_process";
import { promisify } from "node:util";
import path from "node:path";

const run = promisify(execFile);
// HERDR_BIN_PATH is injected by herdr — use it when present so
// the hook talks to the very server that spawned it.
const herdr = process.env.HERDR_BIN_PATH ?? "herdr";

function herdrCall(args) {
  return run(herdr, args).then(({ stdout }) => stdout);
}

function displayName(cwd, home) {
  const short = home && cwd.startsWith(home) ? cwd.replace(home, "~") : cwd;
  return path.basename(short) || short;
}

// A tab's directory: its focused pane's cwd, else its first pane's.
function tabCwd(panes, tabId) {
  const own = panes.filter((p) => p.tab_id === tabId);
  const pane = own.find((p) => p.focused) ?? own[0];
  return pane?.cwd;
}

async function heal() {
  const tabs = JSON.parse(await herdrCall(["tab", "list"])).result.tabs;
  const panes = JSON.parse(await herdrCall(["pane", "list"])).result.panes;
  const home = process.env.HOME;

  // The tab list is grouped by workspace and ordered by
  // position within each workspace — that order is the
  // numbering. (herdr's own "number" field is a creation
  // counter that never renumbers.)
  const byWorkspace = new Map();
  for (const tab of tabs) {
    if (!byWorkspace.has(tab.workspace_id)) {
      byWorkspace.set(tab.workspace_id, []);
    }
    byWorkspace.get(tab.workspace_id).push(tab);
  }

  for (const wsTabs of byWorkspace.values()) {
    for (const [index, tab] of wsTabs.entries()) {
      const position = index + 1;
      let label = null;
      if (/^\d+\. /.test(tab.label)) {
        // Managed label: keep the name, rewrite the number.
        label = `${position}. ${tab.label.match(/^\d+\. (.+)$/)[1]}`;
      } else if (/^\d+$/.test(tab.label)) {
        // Fresh tab: name it after the focused pane's directory.
        const cwd = tabCwd(panes, tab.tab_id);
        if (cwd) label = `${position}. ${displayName(cwd, home)}`;
      }
      // Anything else is a manual rename — leave it alone.
      if (label && label !== tab.label) {
        await herdrCall(["tab", "rename", tab.tab_id, label]);
      }
    }
  }
}

heal().catch(() => process.exit(0));
