#!/usr/bin/env node

// Prefer Hex's documented model-list CLI. Older Linux builds only expose the
// default-model status command, so return that one installed model and route
// changes to Hex's own model UI instead of writing settings.json ourselves.
import { spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const dataRoot = process.env.XDG_DATA_HOME || join(homedir(), ".local", "share");
const hexRoot = join(dataRoot, "hex");
let selectedId = "";
try {
  const settings = JSON.parse(readFileSync(join(hexRoot, "settings.json"), "utf8"));
  selectedId = String(settings.transcription?.model || "");
} catch {}

function run(args) {
  return spawnSync("hex", args, { encoding: "utf8", maxBuffer: 1024 * 1024 });
}

const listed = run(["model", "list", "--json"]);
if (listed.status === 0) {
  try {
    const response = JSON.parse(listed.stdout);
    const models = Array.isArray(response) ? response : response.models;
    if (Array.isArray(models)) {
      process.stdout.write(JSON.stringify({
        models: models.map(model => ({ ...model, selected: !!model.selected || model.id === selectedId })),
        can_select: true,
        note: ""
      }) + "\n");
      process.exit(0);
    }
  } catch {}
}

const current = run(["model", "status"]);
const columns = String(current.stdout || "").trim().split("\t");
if (current.status === 0 && columns[0] === "installed" && columns[1]) {
  process.stdout.write(JSON.stringify({
    models: [{ id: selectedId || columns[1], name: columns[1], size: "Installed default model", installed: true, selected: true }],
    can_select: false,
    note: "Open Hex to switch or install models"
  }) + "\n");
  process.exit(0);
}

process.stderr.write(String(current.stderr || listed.stderr || "Hex model status is unavailable").trim() + "\n");
process.exit(1);
