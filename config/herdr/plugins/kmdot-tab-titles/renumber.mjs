#!/usr/bin/env node
// kmDot herdr plugin event hook — keeps tab labels as
// "<tab number>. <directory>" across tab topology changes.
//
// Closing, opening, or re-ordering tabs shifts every later tab's
// position, and no prompt re-renders in the surviving panes, so the
// fish prompt hook (which only fires on cd) leaves the old number
// prefixes stale. This hook runs on tab.created / tab.closed /
// tab.moved / pane.closed / pane.exited and heals the whole session
// in one pass:
//
//   * "<N>. <name>" labels get their number rewritten to the
//     tab's current position (the name half is kept)
//   * bare-number labels (fresh tabs) get named after the
//     tab's focused pane's directory
//   * anything else — a tab renamed by hand — is left alone
//
// (Closing a tab's last pane emits pane.closed / pane.exited and NO
// tab.closed — hence the pane hooks. The heal is idempotent, so the
// extra events are harmless.)
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
  const home = process.env.HOME;
  let panes = null; // fetched lazily — only bare-number tabs need it
  const seen = new Map(); // workspace_id -> tabs seen so far

  // The tab list is grouped by workspace and ordered by position
  // within each workspace — that order IS the numbering. (herdr's
  // own "number" field is a creation counter that never renumbers:
  // live proof — the "2. kmDot" tab below carries number: 12.)
  for (const tab of tabs) {
    const position = (seen.get(tab.workspace_id) ?? 0) + 1;
    seen.set(tab.workspace_id, position);
    try {
      // Managed labels only: herdr's bare number ("2") or this
      // script's "N. name". Anything else is a manual rename.
      const managed = tab.label.match(/^\d+(?:\. (.*))?$/);
      if (!managed) continue;
      let name = managed[1];
      if (!name) {
        // Fresh tab: name it after the focused pane's directory.
        panes ??= JSON.parse(await herdrCall(["pane", "list"])).result.panes;
        const cwd = tabCwd(panes, tab.tab_id);
        if (!cwd) continue;
        name = displayName(cwd, home);
      }
      // Managed "N. name": the name half is kept, the number is
      // rewritten — so this is a no-op unless the number is stale.
      const label = `${position}. ${name}`;
      if (label !== tab.label) {
        await herdrCall(["tab", "rename", tab.tab_id, label]);
      }
    } catch {
      // One bad label or failed rename must not abort the rest.
    }
  }
}

heal().catch(() => process.exit(0));
