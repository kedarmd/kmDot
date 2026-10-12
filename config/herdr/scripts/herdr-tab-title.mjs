#!/usr/bin/env node
// kmDot herdr tab auto-titler — names every tab "<tab number>. <directory>".
//
// The fish prompt hook (config/fish/config.fish) runs this script with the
// pane's cwd whenever $PWD changes, so a new tab is named at its first prompt
// and renames itself when you cd elsewhere. Tab numbers come straight from
// herdr (1-based, per workspace), so numbering always starts at one.
//
// Manual renames win: only herdr's bare-number labels ("2") and labels this
// script produced ("2. kmDot") are touched. Rename a tab by hand and it is
// left alone; rename it back to a bare number to hand it to the script again.
//
// Silent no-op outside herdr panes or when the server is unreachable — this
// runs on every directory change and must never break the shell prompt.

import { execFile } from "node:child_process";
import { promisify } from "node:util";
import path from "node:path";

const run = promisify(execFile);

// herdr sets these inside every managed pane.
if (process.env.HERDR_ENV !== "1" || !process.env.HERDR_PANE_ID) {
  process.exit(0);
}

// The fish hook passes the shell's live $PWD; fall back to the pane cwd.
const cwdArg = process.argv[2];

function herdr(args) {
  return run("herdr", args).then(({ stdout }) => stdout);
}

function displayName(cwd, home) {
  const short = home && cwd.startsWith(home) ? cwd.replace(home, "~") : cwd;
  return path.basename(short) || short;
}

async function main() {
  // pane current resolves the calling pane's live location (HERDR_PANE_ID),
  // so panes moved between tabs are named after the tab they are in now.
  const pane = JSON.parse(await herdr(["pane", "current"])).result.pane;
  const cwd = cwdArg || pane.cwd || process.cwd();

  // Tab numbers are positions in the workspace's ordered tab list
  // (herdr's own "number" field is a creation counter that never
  // renumbers, so it cannot be used).
  const tabs = JSON.parse(
    await herdr(["tab", "list", "--workspace", pane.workspace_id])
  ).result.tabs;
  const position = tabs.findIndex((t) => t.tab_id === pane.tab_id) + 1;
  if (position === 0) process.exit(0);

  const tab = tabs[position - 1];

  // Managed labels only: herdr's bare number or this script's "N. name".
  if (!/^\d+$/.test(tab.label) && !/^\d+\. /.test(tab.label)) {
    process.exit(0);
  }

  const label = `${position}. ${displayName(cwd, process.env.HOME)}`;
  if (tab.label === label) process.exit(0);

  await herdr(["tab", "rename", tab.tab_id, label]);
}

main().catch(() => process.exit(0));
