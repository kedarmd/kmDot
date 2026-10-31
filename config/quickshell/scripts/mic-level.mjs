#!/usr/bin/env node

// mic-level.mjs — live capture level for one microphone.
//
// The volume popup runs this while open, pointed at the default source, and
// renders its stdout as the input-level meter (pavucontrol's bouncing bar).
// Usage: mic-level.mjs <pipewire-node-name> [--history]
//
// Pipeline: pw-record captures the mic as mono f32le @ 48k to stdout; this
// script folds each chunk to its peak and prints one 0..1 line per ~80ms with
// instant attack + exponential release (meter ballistics). The optional
// --history mode emits the latest 32 levels as JSON for a live waveform. Exit (and the
// popup's revive tick) is the error path: if pw-record dies — mic unplugged,
// BT mic dropped — we exit and the popup restarts us for the new default.

import { spawn } from "node:child_process";

const target = process.argv[2];
const historyMode = process.argv[3] === "--history";
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
let squareSum = 0;
let sampleCount = 0;
let level = 0;
let noiseFloor = 0.025;
let lastEmit = 0;
const samples = Array(32).fill(0);
const samplesPerBar = 90; // 1.875ms at 48kHz; 32 bars cover the latest 60ms.
const framePeaks = [];
let barPeak = 0;
let barSampleCount = 0;
let frameSquareSum = 0;
let frameSampleCount = 0;

rec.stdout.on("data", chunk => {
  const buf = Buffer.concat([leftover, chunk]);
  const n = Math.floor(buf.length / 4);
  for (let i = 0; i < n; i++) {
    const raw = buf.readFloatLE(i * 4);
    const v = Math.abs(raw);
    if (Number.isFinite(v) && v > peak) peak = v;
    if (Number.isFinite(raw)) {
      squareSum += raw * raw;
      sampleCount++;

      if (historyMode) {
        if (v > barPeak) barPeak = v;
        barSampleCount++;
        frameSquareSum += raw * raw;
        frameSampleCount++;

        if (barSampleCount >= samplesPerBar) {
          framePeaks.push(barPeak);
          barPeak = 0;
          barSampleCount = 0;

          if (framePeaks.length === samples.length) {
            const rms = Math.sqrt(frameSquareSum / frameSampleCount);
            // Learn only from quieter frames so speech cannot raise the noise gate.
            if (rms < noiseFloor * 1.7) {
              const rate = rms > noiseFloor ? 0.08 : 0.015;
              noiseFloor += (rms - noiseFloor) * rate;
            }
            const threshold = Math.max(0.02, noiseFloor * 1.4);
            for (let j = 0; j < samples.length; j++) {
              const measured = Math.min(1, Math.max(0, framePeaks[j] - threshold) * 6.5);
              samples[j] = Math.max(measured, samples[j] * 0.4);
            }
            process.stdout.write(JSON.stringify(samples) + "\n");
            framePeaks.length = 0;
            frameSquareSum = 0;
            frameSampleCount = 0;
          }
        }
      }
    }
  }
  leftover = buf.subarray(n * 4);

  if (historyMode) return;

  const now = Date.now();
  if (now - lastEmit >= 80) {
    lastEmit = now;
    level = Math.max(Math.min(1, peak), level * 0.72);
    peak = 0;
    squareSum = 0;
    sampleCount = 0;
    process.stdout.write(level.toFixed(3) + "\n");
  }
});
