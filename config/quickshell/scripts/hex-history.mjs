#!/usr/bin/env node

// Read Hex's versioned v1 retained-history document without modifying it.
// The schema and retention behavior are documented in Hex's transcript CLI;
// this bridge is for installed builds whose Linux CLI lacks `hex history`.
import { readFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";

const dataRoot = process.env.XDG_DATA_HOME || join(homedir(), ".local", "share");
const file = join(dataRoot, "hex", "history.json");
const settingsFile = join(dataRoot, "hex", "settings.json");

try {
  const value = JSON.parse(await readFile(file, "utf8"));
  if (value.version !== 1 || !Array.isArray(value.entries)) {
    throw new Error("Unsupported history format");
  }
  const entries = value.entries
    .filter(entry => Number.isFinite(Number(entry.id))
      && Number.isFinite(Number(entry.timestamp_ms))
      && typeof entry.final_text === "string")
    .map(entry => ({
      id: Number(entry.id),
      timestamp_ms: Number(entry.timestamp_ms),
      kind: String(entry.kind || "dictation"),
      final_text: entry.final_text,
    }))
    .sort((a, b) => b.timestamp_ms - a.timestamp_ms)
    .slice(0, 50);
  let selected_model = "";
  try {
    const settings = JSON.parse(await readFile(settingsFile, "utf8"));
    selected_model = String(settings.transcription?.model || "");
  } catch {}
  process.stdout.write(JSON.stringify({ version: 1, selected_model, entries }) + "\n");
} catch (error) {
  process.stderr.write(`hex-history: ${error.message}\n`);
  process.exitCode = 1;
}
