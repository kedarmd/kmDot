#!/usr/bin/env node

import { execFileSync } from "node:child_process";

const sumTokens = tokens => {
  const value = tokens || {};
  const cache = value.cache || {};
  return Number(value.input || 0)
    + Number(value.output || 0)
    + Number(value.reasoning || 0)
    + Number(cache.read || 0)
    + Number(cache.write || 0);
};

const dateKey = date => [
  date.getFullYear(),
  String(date.getMonth() + 1).padStart(2, "0"),
  String(date.getDate()).padStart(2, "0")
].join("-");

try {
  const raw = execFileSync("opencode", ["stats", "--days", "7", "--json", "--cost", "--models"], {
    encoding: "utf8",
    maxBuffer: 8 * 1024 * 1024,
    stdio: ["ignore", "pipe", "pipe"]
  });
  const stats = JSON.parse(raw);
  const today = new Date();
  const days = [];

  for (let offset = 6; offset >= 0; offset--) {
    const date = new Date(today.getFullYear(), today.getMonth(), today.getDate() - offset);
    const key = dateKey(date);
    const activity = (stats.activity || []).find(entry => entry.date === key);
    days.push({
      date: key,
      label: date.toLocaleDateString(undefined, { weekday: "short" }),
      steps: Number(activity?.steps || 0)
    });
  }

  const models = (stats.models || []).map(entry => ({
    model: String(entry.model?.id || entry.model?.providerID || "Unknown model"),
    tokens: sumTokens(entry.tokens),
    cost: Number(entry.cost || 0)
  })).sort((a, b) => b.tokens - a.tokens);

  process.stdout.write(JSON.stringify({
    ok: true,
    days,
    models,
    total: {
      tokens: sumTokens(stats.tokens),
      cost: Number(stats.cost || 0)
    },
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
