#!/usr/bin/env node

import { execFileSync } from "node:child_process";

const now = new Date();
const start = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 6);
const startMs = start.getTime();
const sql = [
  "SELECT date(time_created / 1000, 'unixepoch', 'localtime') AS day,",
  "json_extract(data, '$.providerID') || '/' || json_extract(data, '$.modelID') AS model,",
  "SUM(COALESCE(json_extract(data, '$.tokens.input'), 0)",
  " + COALESCE(json_extract(data, '$.tokens.output'), 0)",
  " + COALESCE(json_extract(data, '$.tokens.reasoning'), 0)",
  " + COALESCE(json_extract(data, '$.tokens.cache.read'), 0)",
  " + COALESCE(json_extract(data, '$.tokens.cache.write'), 0)) AS tokens,",
  "SUM(COALESCE(json_extract(data, '$.cost'), 0)) AS cost",
  "FROM message",
  `WHERE time_created >= ${startMs} AND json_extract(data, '$.role') = 'assistant'`,
  "GROUP BY day, model"
].join(" ");

const dayKey = date => {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, "0");
  const d = String(date.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
};

const emptyTotals = () => ({ tokens: 0, cost: 0 });

const days = [];
for (let i = 0; i < 7; i++) {
  const date = new Date(startMs);
  date.setDate(date.getDate() + i);
  days.push({ date: dayKey(date), label: date.toLocaleDateString(undefined, { weekday: "short" }), ...emptyTotals() });
}

try {
  const raw = execFileSync("opencode", ["db", sql, "--format", "json"], {
    encoding: "utf8",
    maxBuffer: 8 * 1024 * 1024,
    stdio: ["ignore", "pipe", "pipe"]
  });
  const rows = JSON.parse(raw);
  const byDay = Object.fromEntries(days.map(day => [day.date, day]));
  const byModel = new Map();

  for (const row of rows) {
    const tokens = Number(row.tokens || 0);
    const cost = Number(row.cost || 0);
    const day = byDay[row.day];
    if (day) {
      day.tokens += tokens;
      day.cost += cost;
    }
    const key = String(row.model || "unknown/unknown");
    if (!byModel.has(key)) byModel.set(key, { model: key, ...emptyTotals() });
    const bucket = byModel.get(key);
    bucket.tokens += tokens;
    bucket.cost += cost;
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
  const detail = error.stderr ? String(error.stderr).split("\n").find(Boolean) : "";
  process.stdout.write(JSON.stringify({
    ok: false,
    error: error.code === "ENOENT"
      ? "OpenCode CLI not found"
      : "Could not read OpenCode usage" + (detail ? ` (${detail.slice(0, 120)})` : "")
  }));
}
