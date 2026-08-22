#!/usr/bin/env node

import { execFileSync } from "node:child_process";

const now = new Date();
const start = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 6);
const startMs = start.getTime();
const sql = `SELECT data FROM message WHERE time_created >= ${startMs} ORDER BY time_created ASC`;

const dayKey = date => {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, "0");
  const d = String(date.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
};

const emptyTotals = () => ({ tokens: 0, cost: 0 });
const addTokens = (data, totals) => {
  const tokens = data.tokens || {};
  const cache = tokens.cache || {};
  totals.tokens += Number(tokens.input || 0) + Number(tokens.output || 0)
    + Number(tokens.reasoning || 0) + Number(cache.read || 0) + Number(cache.write || 0);
  totals.cost += Number(data.cost || 0);
};

const days = [];
for (let i = 0; i < 7; i++) {
  const date = new Date(startMs);
  date.setDate(date.getDate() + i);
  days.push({ date: dayKey(date), label: date.toLocaleDateString(undefined, { weekday: "short" }), ...emptyTotals() });
}

try {
  const raw = execFileSync("opencode", ["db", sql, "--format", "json"], {
    encoding: "utf8",
    maxBuffer: 32 * 1024 * 1024,
    stdio: ["ignore", "pipe", "pipe"]
  });
  const rows = JSON.parse(raw);
  const byDay = Object.fromEntries(days.map(day => [day.date, day]));
  const byModel = new Map();

  for (const row of rows) {
    let data;
    try { data = JSON.parse(row.data); } catch { continue; }
    if (data.role !== "assistant") continue;
    const timestamp = Number(data.time?.created || 0);
    const date = new Date(timestamp || Number(row.time_created || 0));
    const day = byDay[dayKey(date)];
    if (!day) continue;

    addTokens(data, day);
    const provider = String(data.providerID || "unknown");
    const model = String(data.modelID || "unknown");
    const key = `${provider}/${model}`;
    if (!byModel.has(key)) byModel.set(key, { model: key, ...emptyTotals() });
    addTokens(data, byModel.get(key));
  }

  const total = days.reduce((sum, day) => ({
    tokens: sum.tokens + day.tokens,
    cost: sum.cost + day.cost
  }), emptyTotals());
  process.stdout.write(JSON.stringify({
    ok: true,
    days,
    models: [...byModel.values()].sort((a, b) => b.tokens - a.tokens),
    total,
    generatedAt: Date.now()
  }));
} catch (error) {
  process.stdout.write(JSON.stringify({
    ok: false,
    error: error.code === "ENOENT" ? "OpenCode CLI not found" : "Could not read OpenCode usage"
  }));
}
