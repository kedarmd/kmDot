#!/usr/bin/env node

import { execFileSync, spawn } from "node:child_process";
import { existsSync, readFileSync, renameSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const home = homedir();
const dataDir = join(home, ".local", "share", "com.pais.handy");
const settingsFile = join(dataDir, "settings_store.json");
const historyFile = join(dataDir, "history.db");
const recordingsDir = join(dataDir, "recordings");
const handy = join(home, ".local", "bin", "handy");

const output = value => process.stdout.write(JSON.stringify(value));
const fail = error => output({ ok: false, error: String(error.message || error) });

function sqlString(value) {
  return "'" + String(value).replaceAll("'", "''") + "'";
}

function sqlite(sql, write = false) {
  if (!existsSync(historyFile)) throw new Error("Handy history database not found");
  if (!write && !existsSync("/usr/bin/sqlite3") && !existsSync("/bin/sqlite3")) {
    throw new Error("sqlite3 is required to read Handy history");
  }
  return execFileSync("sqlite3", write ? [historyFile, "-cmd", "PRAGMA busy_timeout=3000", sql]
    : ["-readonly", historyFile, ".mode json", sql], { encoding: "utf8", maxBuffer: 8 * 1024 * 1024 });
}

function settings() {
  if (!existsSync(settingsFile)) throw new Error("Handy settings not found");
  return JSON.parse(readFileSync(settingsFile, "utf8"));
}

function writeSettings(data) {
  const temporary = settingsFile + ".kmdot-tmp-" + process.pid;
  writeFileSync(temporary, JSON.stringify(data, null, 2) + "\n", { mode: 0o600 });
  renameSync(temporary, settingsFile);
}

function listModels() {
  const raw = execFileSync(handy, ["--list-models", "--json"], {
    encoding: "utf8", maxBuffer: 32 * 1024 * 1024
  });
  const catalog = JSON.parse(raw);
  const selected = settings().settings?.selected_model || "";
  return {
    ok: true,
    selected,
    models: catalog.filter(model => model.is_downloaded).map(model => ({
      id: String(model.id),
      name: String(model.name || model.id),
      description: String(model.description || ""),
      engine: String(model.engine_type || "")
    }))
  };
}

function listHistory() {
  const raw = sqlite(`SELECT id, file_name, timestamp, title, transcription_text,
    post_processed_text, post_process_requested
    FROM transcription_history ORDER BY timestamp DESC LIMIT 5;`);
  const rows = JSON.parse(raw || "[]").map(row => ({
    id: Number(row.id),
    fileName: String(row.file_name || ""),
    timestamp: Number(row.timestamp || 0),
    title: String(row.title || ""),
    text: String(row.post_processed_text ?? row.transcription_text ?? ""),
    rawText: String(row.transcription_text ?? ""),
    failed: !String(row.transcription_text ?? "").trim(),
    audioAvailable: existsSync(join(recordingsDir, String(row.file_name || ""))),
    postProcessed: row.post_processed_text != null,
    postProcessRequested: Boolean(Number(row.post_process_requested || 0))
  }));
  return { ok: true, history: rows };
}

function selectModel(id) {
  const data = settings();
  if (!data.settings) throw new Error("Invalid Handy settings");
  data.settings.selected_model = String(id);
  writeSettings(data);
  let restarted = false;
  try {
    execFileSync("pgrep", ["-x", "handy"], { stdio: "ignore" });
    execFileSync("pkill", ["-x", "handy"], { stdio: "ignore" });
    const child = spawn(handy, ["--start-hidden"], { detached: true, stdio: "ignore" });
    child.unref();
    restarted = true;
  } catch {
    // Handy is not running; the persisted setting applies on its next launch.
  }
  return { ok: true, selected: String(id), restarted };
}

function updateText(id, text) {
  sqlite(`BEGIN IMMEDIATE;
UPDATE transcription_history SET transcription_text=${sqlString(text)},
post_processed_text=NULL, post_process_requested=0 WHERE id=${Number(id)};
COMMIT;`, true);
  return { ok: true };
}

function retry(id, model) {
  const rows = JSON.parse(sqlite(`SELECT file_name FROM transcription_history WHERE id=${Number(id)} LIMIT 1;`));
  if (!rows.length) throw new Error("Recording not found");
  const recording = join(recordingsDir, rows[0].file_name);
  if (!existsSync(recording)) throw new Error("Recording audio file not found");
  const args = ["--transcribe-file", recording, "--json"];
  if (model) args.push("--model", String(model));
  const raw = execFileSync(handy, args, { encoding: "utf8", maxBuffer: 8 * 1024 * 1024 });
  const result = JSON.parse(raw);
  const text = typeof result === "string"
    ? result
    : String(result.text ?? result.transcription ?? result.transcription_text ?? result.result ?? "");
  if (!text.trim()) throw new Error(String(result.error || "Handy returned an empty transcription"));
  updateText(id, text);
  return { ok: true, id: Number(id), text };
}

try {
  const [command, ...args] = process.argv.slice(2);
  if (command === "models") output(listModels());
  else if (command === "history") output(listHistory());
  else if (command === "select-model" && args[0]) output(selectModel(args[0]));
  else if (command === "save" && args[0] !== undefined) output(updateText(args[0], args.slice(1).join("\n")));
  else if (command === "retry" && args[0]) output(retry(args[0], args[1]));
  else throw new Error("Usage: handy-control.mjs models|history|select-model ID|save ID TEXT|retry ID [MODEL]");
} catch (error) {
  fail(error);
}
