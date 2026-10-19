#!/usr/bin/env node

import { execFileSync } from "node:child_process";
import { existsSync, readdirSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const home = homedir();
const providers = [
  { id: "opencode", name: "OpenCode", bin: "opencode" },
  { id: "codex", name: "Codex", bin: "codex" },
  { id: "pi", name: "Pi", bin: "pi" }
];
const available = providers.filter(provider => {
  try { execFileSync("which", [provider.bin], { stdio: "ignore" }); return true; }
  catch { return false; }
});
const dateKey = date => `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(date.getDate()).padStart(2, "0")}`;
const makeDays = () => Array.from({ length: 7 }, (_, index) => {
  const date = new Date(); date.setHours(0, 0, 0, 0); date.setDate(date.getDate() - (6 - index));
  return { date: dateKey(date), label: date.toLocaleDateString(undefined, { weekday: "short" }), tokens: 0 };
});
const jsonlFiles = (dir, maxDepth = 5, depth = 0) => {
  if (depth > maxDepth || !existsSync(dir)) return [];
  let out = [];
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const path = join(dir, entry.name);
    if (entry.isFile() && entry.name.endsWith(".jsonl")) out.push(path);
    else if (entry.isDirectory()) out = out.concat(jsonlFiles(path, maxDepth, depth + 1));
  }
  return out;
};
const readRows = path => {
  try { return readFileSync(path, "utf8").split("\n").filter(Boolean).map(line => JSON.parse(line)); }
  catch { return []; }
};
const finish = (days, models, total, extra = {}) => process.stdout.write(JSON.stringify({
  ok: true, days, models: [...models.values()].sort((a, b) => b.tokens - a.tokens), total,
  generatedAt: Date.now(), ...extra
}));

function opencode() {
  const stats = JSON.parse(execFileSync("opencode", ["stats", "--days", "7", "--json", "--cost", "--models"], { encoding: "utf8", maxBuffer: 8 * 1024 * 1024, stdio: ["ignore", "pipe", "pipe"] }));
  const days = makeDays();
  const byDate = new Map(days.map(day => [day.date, day]));
  const models = new Map();
  const sessionList = JSON.parse(execFileSync("opencode", ["api", "session.list"], { encoding: "utf8", maxBuffer: 8 * 1024 * 1024, stdio: ["ignore", "pipe", "pipe"] }));
  for (const session of sessionList.data || []) {
    const date = dateKey(new Date(Number(session.time?.updated || session.time?.created || 0)));
    if (!byDate.has(date)) continue;
    const usage = session.tokens || {};
    const tokens = Number(usage.input || 0) + Number(usage.output || 0) + Number(usage.reasoning || 0) + Number(usage.cache?.read || 0) + Number(usage.cache?.write || 0);
    byDate.get(date).tokens += tokens;
    const model = String(session.model?.id || session.model?.providerID || "Unknown model");
    const entry = models.get(model) || { model, tokens: 0, cost: 0 };
    entry.tokens += tokens;
    entry.cost += Number(session.cost || 0);
    models.set(model, entry);
  }
  const sum = value => Number(value?.input || 0) + Number(value?.output || 0) + Number(value?.reasoning || 0) + Number(value?.cache?.read || 0) + Number(value?.cache?.write || 0);
  finish(days, models, { tokens: sum(stats.tokens), cost: Number(stats.cost || 0) });
}

function codex() {
  const days = makeDays();
  const byDate = new Map(days.map(day => [day.date, day]));
  const models = new Map();
  let weeklyLimit = null;
  const root = join(home, ".codex", "sessions");
  for (const path of jsonlFiles(root, 6)) {
    for (const row of readRows(path)) {
      const date = String(row.timestamp || "").slice(0, 10);
      if (row.type === "token_usage_record" && byDate.has(date)) {
        const usage = row.payload?.usage || {};
        byDate.get(date).tokens += Number(usage.total_tokens || 0);
        const model = String(row.payload?.model || "Codex");
        const entry = models.get(model) || { model, tokens: 0, cost: 0 };
        entry.tokens += Number(usage.total_tokens || 0); models.set(model, entry);
      }
      if (row.type === "event_msg" && row.payload?.type === "token_count") {
        const limit = row.payload.info?.rate_limits?.secondary;
        if (limit && Number.isFinite(Number(limit.used_percent))) weeklyLimit = { usedPercent: Math.round(Number(limit.used_percent)), windowMinutes: Number(limit.window_minutes || 10080), resetsAt: Number(limit.resets_at || 0) };
      }
    }
  }
  for (const day of days) day.tokens = Number(day.tokens || 0);
  finish(days, models, { tokens: days.reduce((sum, day) => sum + day.tokens, 0), cost: 0, costAvailable: false }, { weeklyLimit });
}

function pi() {
  const days = makeDays(); const byDate = new Map(days.map(day => [day.date, day]));
  const models = new Map(); let cost = 0; let tokens = 0;
  for (const path of jsonlFiles(join(home, ".pi", "agent", "sessions"), 6)) {
    for (const row of readRows(path)) {
      if (row.type !== "message" || row.message?.role !== "assistant" || !row.message?.usage) continue;
      const timestamp = Number(row.message.timestamp || Date.parse(row.timestamp || ""));
      const date = dateKey(new Date(timestamp)); const usage = row.message.usage;
      const count = Number(usage.totalTokens || 0);
      if (!byDate.has(date)) continue;
      byDate.get(date).tokens += count; tokens += count;
      const model = String(row.message.model || "Unknown model");
      const entry = models.get(model) || { model, tokens: 0, cost: 0 };
      entry.tokens += count; entry.cost += Number(usage.cost?.total || 0); models.set(model, entry);
      cost += Number(usage.cost?.total || 0);
    }
  }
  for (const day of days) day.tokens = Number(day.tokens || 0);
  finish(days, models, { tokens, cost });
}

try {
  if (process.argv[2] === "--list") {
    process.stdout.write(JSON.stringify({ agents: available }));
  } else {
    const id = process.argv[2] || "opencode";
    if (!available.some(provider => provider.id === id)) throw new Error(`${id} CLI not found`);
    if (id === "opencode") opencode();
    else if (id === "codex") codex();
    else if (id === "pi") pi();
  }
} catch (error) {
  const detail = error.stderr ? String(error.stderr).split("\n").find(Boolean) : error.message;
  process.stdout.write(JSON.stringify({ ok: false, error: `Could not read ${process.argv[2] || "agent"} usage${detail ? ` (${String(detail).slice(0, 120)})` : ""}` }));
}
