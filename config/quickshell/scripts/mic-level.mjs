#!/usr/bin/env node

// mic-level.mjs — live capture level for one microphone.
//
// The volume popup runs this while open, pointed at the default source, and
// renders its stdout as the input-level meter (pavucontrol's bouncing bar).
// Usage: mic-level.mjs <pipewire-node-name>
//
// Pipeline: pw-record captures the mic as mono f32le @ 48k to stdout; this
// script folds each chunk to its peak and prints one 0..1 line per ~80ms with
// instant attack + exponential release (meter ballistics). Exit (and the
// popup's revive tick) is the error path: if pw-record dies — mic unplugged,
// BT mic dropped — we exit and the popup restarts us for the new default.

import { spawn } from "node:child_process";

const target = process.argv[2];
if (!target) {
  process.stderr.write("mic-level.mjs: missing <pipewire-node-name>\n");
  process.exit(2);
}

const rec = spawn("pw-record", [
  "--target", target,
  "--format", "f32",
  "--channels", "1",
  "--rate", "48000",
  "-",
], { stdio: ["ignore", "pipe", "ignore"] });

rec.on("error", () => process.exit(1));
rec.on("close", () => process.exit(0));

function shutdown() {
  try { rec.kill("SIGTERM"); } catch (e) {}
}
process.on("SIGTERM", shutdown);
process.on("SIGINT", shutdown);
// Backstop against orphans: an uncaught exception (e.g. EPIPE on a dead
// stdout) must still take the pw-record child down with us.
process.on("exit", () => {
  try { rec.kill("SIGKILL"); } catch (e) {}
});
process.stdout.on("error", () => process.exit(0));

let leftover = Buffer.alloc(0);
let peak = 0;
let level = 0;
let lastEmit = 0;

rec.stdout.on("data", chunk => {
  const buf = Buffer.concat([leftover, chunk]);
  const n = Math.floor(buf.length / 4);
  for (let i = 0; i < n; i++) {
    const v = Math.abs(buf.readFloatLE(i * 4));
    if (Number.isFinite(v) && v > peak) peak = v;
  }
  leftover = buf.subarray(n * 4);

  const now = Date.now();
  if (now - lastEmit >= 80) {
    lastEmit = now;
    level = Math.max(Math.min(1, peak), level * 0.72);
    peak = 0;
    process.stdout.write(level.toFixed(3) + "\n");
  }
});
