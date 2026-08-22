#!/usr/bin/env node
// Parse ~/.cache/kmdot/calendar.ics into a JSON map keyed by local date.
//
// Output: {"ok": bool, "events": {"YYYY-MM-DD": [{"s":"HH:MM","e":"HH:MM","t":title,"a":allDay}, ...]}}
//
// - All-day events have "a": true and empty s/e.
// - Recurring events (RRULE) are expanded (DAILY/WEEKLY/MONTHLY/YEARLY with
//   BYDAY, INTERVAL, COUNT/UNTIL, BYMONTHDAY/BYMONTH), bounded to a window.
// - TZID / UTC / date-only values are handled; tz data comes from the system
//   tz database via Node's Intl (no external packages).
// - Events are included for [today-400d, today+400d] so month navigation has data.
//
// Only depends on Node.js — no npm packages.

import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const DAY_MS = 86400000;
const today = new Date();
today.setHours(0, 0, 0, 0);
const WINDOW_START = today.getTime() - 400 * DAY_MS;
const WINDOW_END = today.getTime() + 400 * DAY_MS;

// ---- date helpers (calendar arithmetic is separate from instants) ----

// Parse "YYYYMMDD" or "YYYYMMDDTHHMMSS" / "...THHMM" into a Date in the given
// IANA timezone (defaults to the local timezone). Returns {date, allDay}.
function parseDt(value, tzid) {
  let v = String(value).trim();
  if (v.startsWith(";")) v = v.split(":", 1)[1] || v;
  // date-only
  if (v.length === 8 && /^\d{8}$/.test(v)) {
    const iso = `${v.slice(0, 4)}-${v.slice(4, 6)}-${v.slice(6, 8)}T00:00:00`;
    const date = tzid ? new Date(toZonedISO(iso, tzid)) : new Date(iso);
    return { date, allDay: true };
  }
  // strip trailing Z (UTC)
  const isZ = v.endsWith("Z");
  if (isZ) v = v.slice(0, -1);
  let m = /^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})?$/.exec(v);
  let sec = "00";
  if (!m) {
    m = /^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})$/.exec(v);
  } else {
    sec = m[6];
  }
  if (!m) return { date: null, allDay: false };
  const iso = `${m[1]}-${m[2]}-${m[3]}T${m[4]}:${m[5]}:${sec}`;
  let dt;
  if (isZ) {
    dt = new Date(iso + "Z");
  } else if (tzid) {
    dt = new Date(toZonedISO(iso, tzid));
  } else {
    dt = new Date(iso);
  }
  return { date: Number.isNaN(dt.getTime()) ? null : dt, allDay: false };
}

// Convert a local wall-clock time in `tz` into a Date by resolving through UTC
// offset lookup (fixed-point iteration handles DST edges correctly).
function toZonedISO(iso, tz) {
  const base = new Date(iso + "Z").getTime();
  let guess = base;
  let prev = null;
  for (let i = 0; i < 3; i++) {
    const off = offsetAt(new Date(guess), tz); // offset such that guess+off = local in tz
    const cand = base - off;
    if (prev !== null && prev === off) return new Date(cand).toISOString();
    prev = off;
    guess = cand;
  }
  return new Date(guess).toISOString();
}

// Offset (in ms) such that UTC + offset = local time in tz at instant `date`.
function offsetAt(date, tz) {
  const utc = date.getTime();
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: tz,
    year: "numeric", month: "2-digit", day: "2-digit",
    hour: "2-digit", minute: "2-digit", second: "2-digit",
    hourCycle: "h23",
  }).formatToParts(date);
  const read = (t) => parts.find((p) => p.type === t)?.value;
  const local = Date.UTC(+read("year"), +read("month") - 1, +read("day"),
    +read("hour"), +read("minute"), +read("second"));
  return local - utc;
}

function toLocal(date) {
  return date; // Date already holds an absolute instant; formatting uses local tz
}

function zonedParts(date, tz) {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: tz, year: "numeric", month: "2-digit", day: "2-digit",
    hour: "2-digit", minute: "2-digit", second: "2-digit", hourCycle: "h23",
  }).formatToParts(date);
  const read = (type) => Number(parts.find((p) => p.type === type)?.value);
  return { y: read("year"), mo: read("month") - 1, d: read("day"),
    h: read("hour"), m: read("minute"), s: read("second") };
}

function civilDate(y, mo, d, h = 0, m = 0, s = 0) {
  return new Date(Date.UTC(y, mo, d, h, m, s));
}

function civilParts(date) {
  return { y: date.getUTCFullYear(), mo: date.getUTCMonth(), d: date.getUTCDate(),
    h: date.getUTCHours(), m: date.getUTCMinutes(), s: date.getUTCSeconds() };
}

function civilToInstant(date, tzid) {
  const p = civilParts(date);
  if (!tzid) return new Date(p.y, p.mo, p.d, p.h, p.m, p.s);
  const pad = (n) => String(n).padStart(2, "0");
  return new Date(toZonedISO(`${String(p.y).padStart(4, "0")}-${pad(p.mo + 1)}-${pad(p.d)}T${pad(p.h)}:${pad(p.m)}:${pad(p.s)}`, tzid));
}

// ---- RRULE expansion (bounded to the window) ----

const DOW = { SU: 0, MO: 1, TU: 2, WE: 3, TH: 4, FR: 5, SA: 6 };
const DOW_NAME = { SUN: 0, MON: 1, TUE: 2, WED: 3, THU: 4, FRI: 5, SAT: 6 };

// Parse an RRULE string into a rule object.
function parseRule(str, tzid) {
  const rule = { freq: null, interval: 1, count: Infinity, until: Infinity, byday: null, bymonth: null, bymonthday: null };
  for (const part of String(str).split(";")) {
    const eq = part.indexOf("=");
    if (eq < 0) continue;
    const k = part.slice(0, eq).toUpperCase();
    const v = part.slice(eq + 1);
    if (k === "FREQ") rule.freq = v.toUpperCase();
    else if (k === "INTERVAL") rule.interval = Math.max(1, parseInt(v, 10) || 1);
    else if (k === "COUNT") rule.count = parseInt(v, 10) || Infinity;
    else if (k === "UNTIL") rule.until = parseDt(v, tzid).date?.getTime() ?? Infinity;
    else if (k === "BYDAY") rule.byday = v.split(",").map((s) => s.trim().toUpperCase());
    else if (k === "BYMONTH") rule.bymonth = v.split(",").map((s) => parseInt(s, 10));
    else if (k === "BYMONTHDAY") rule.bymonthday = v.split(",").map((s) => parseInt(s, 10));
  }
  return rule;
}

// Advance a local date by `interval` units of `freq`, returning a new Date.
function advance(date, freq, interval) {
  const d = new Date(date.getTime());
  const y = d.getFullYear();
  const mo = d.getMonth();
  if (freq === "DAILY") {
    d.setDate(d.getDate() + interval);
  } else if (freq === "WEEKLY") {
    d.setDate(d.getDate() + 7 * interval);
  } else if (freq === "MONTHLY") {
    d.setMonth(mo + interval);
  } else if (freq === "YEARLY") {
    d.setFullYear(y + interval);
  }
  return d;
}

function weekdayOf(d) { return d.getDay(); }

// Re-apply the DTSTART's time-of-day (H:M:S) onto a candidate date.
function atStartTime(cand, startLocal, startHMS) {
  const c = new Date(cand.getTime());
  c.setHours(startHMS.h, startHMS.m, startHMS.s, 0);
  return c;
}

// Expand a rule from a start date into a list of local dates (bounded).
// Generates candidate dates per FREQ, then filters by BYDAY/BYMONTH/BYMONTHDAY.
function expandRule(rule, start, tzid) {
  const out = [];
  if (!rule.freq) return [start];
  const sp = tzid ? zonedParts(start, tzid) : {
    y: start.getFullYear(), mo: start.getMonth(), d: start.getDate(),
    h: start.getHours(), m: start.getMinutes(), s: start.getSeconds(),
  };
  const startLocal = new Date(sp.y, sp.mo, sp.d, sp.h, sp.m, sp.s);
  const startHMS = { h: startLocal.getHours(), m: startLocal.getMinutes(), s: startLocal.getSeconds() };
  startLocal.setHours(0, 0, 0, 0);
  const freq = rule.freq;
  const interval = rule.interval;

  // parse BYDAY into [{ord, day}] (ord=0 means "every such weekday")
  const byday = rule.byday
    ? rule.byday.map((s) => {
        const m = /^(-?\d+)?(SU|MO|TU|WE|TH|FR|SA)$/.exec(s);
        if (!m) return null;
        return { ord: m[1] ? parseInt(m[1], 10) : 0, day: DOW[m[2]] };
      }).filter(Boolean)
    : null;

  const candidates = [];

  if (freq === "DAILY") {
    for (let i = 0; i < 2000; i++) {
      candidates.push(new Date(startLocal.getTime() + i * interval * DAY_MS));
      if (candidates[i].getTime() > WINDOW_END + DAY_MS) break;
    }
  } else if (freq === "WEEKLY") {
    const startDow = weekdayOf(startLocal);
    if (!byday) {
      for (let i = 0; i < 200; i++) {
        candidates.push(new Date(startLocal.getTime() + i * 7 * interval * DAY_MS));
        if (candidates[i].getTime() > WINDOW_END + DAY_MS) break;
      }
    } else {
      // weeks are counted from the DTSTART's week-start (Sunday)
      const startWeek = new Date(startLocal.getTime() - startDow * DAY_MS);
      for (let w = 0; w < 600; w++) {
        const weekStart = new Date(startWeek.getTime() + w * 7 * DAY_MS);
        if (weekStart.getTime() > WINDOW_END + 7 * DAY_MS) break;
        if (w % interval !== 0) continue;
        for (const b of byday) {
          const cand = new Date(weekStart.getTime() + b.day * DAY_MS);
          if (cand.getTime() < startLocal.getTime()) continue;
          candidates.push(atStartTime(cand, startLocal, startHMS));
        }
      }
    }
  } else if (freq === "MONTHLY") {
    const sy = startLocal.getFullYear();
    const sm = startLocal.getMonth();
    for (let i = 0; i < 400; i++) {
      const abs = sy * 12 + sm + i * interval;
      const y = Math.floor(abs / 12);
      const m = abs % 12;
      const lastDay = new Date(y, m + 1, 0).getDate();
      if (byday && byday.some((b) => b.ord !== 0)) {
        // ordinal weekday form (e.g. "2TU" = 2nd Tuesday): all such days this month
        for (const b of byday) {
          if (b.ord === 0) continue;
          const days = [];
          for (let d = 1; d <= lastDay; d++) {
            const c = new Date(y, m, d);
            if (weekdayOf(c) === b.day) days.push(c);
          }
          if (days.length) {
            const pick = b.ord > 0 ? days[b.ord - 1] : days[days.length + b.ord];
            if (pick) candidates.push(atStartTime(pick, startLocal, startHMS));
          }
        }
      } else if (byday && byday.every((b) => b.ord === 0)) {
        // every weekday: each such weekday in the month
        for (let d = 1; d <= lastDay; d++) {
          const c = new Date(y, m, d);
          if (byday.some((b) => b.day === weekdayOf(c))) candidates.push(atStartTime(c, startLocal, startHMS));
        }
      } else if (rule.bymonthday) {
        const days = rule.bymonthday
          .map((d) => (d < 0 ? lastDay + d + 1 : d))
          .filter((d) => d >= 1 && d <= lastDay);
        for (const d of days) candidates.push(atStartTime(new Date(y, m, d), startLocal));
      } else {
        candidates.push(atStartTime(new Date(y, m, Math.min(startLocal.getDate(), lastDay)), startLocal));
      }
      if (abs > new Date(WINDOW_END).getFullYear() * 12 + new Date(WINDOW_END).getMonth() + 12) break;
    }
  } else if (freq === "YEARLY") {
    for (let i = 0; i < 100; i++) {
      const c = new Date(startLocal.getTime());
      c.setFullYear(startLocal.getFullYear() + i * interval);
      candidates.push(atStartTime(c, startLocal, startHMS));
    }
  }

  // filter + apply COUNT/UNTIL/byday/bymonth/by-month-day
  let count = 0;
  for (const cand of candidates) {
    const instant = tzid
      ? civilToInstant(civilDate(cand.getFullYear(), cand.getMonth(), cand.getDate(), cand.getHours(), cand.getMinutes(), cand.getSeconds()), tzid)
      : cand;
    if (instant.getTime() < start.getTime()) continue;
    if (instant.getTime() > rule.until) break;
    if (instant.getTime() > WINDOW_END) break;
    if (byday && freq !== "WEEKLY" && freq !== "MONTHLY") {
      const wd = weekdayOf(cand);
      if (!byday.some((b) => b.day === wd)) continue;
    }
    if (freq === "WEEKLY" && byday) {
      const wd = weekdayOf(cand);
      if (!byday.some((b) => b.day === wd)) continue;
    }
    if (rule.bymonth && !rule.bymonth.includes(cand.getMonth() + 1)) continue;
    if (instant.getTime() >= WINDOW_START) out.push(new Date(instant.getTime()));
    count++;
    if (rule.count !== Infinity && count >= rule.count) break;
  }
  return out;
}

// ---- ICS parsing ----

function splitValue(line) {
  const idx = line.indexOf(":");
  if (idx < 0) return { name: line, params: {}, value: "" };
  const head = line.slice(0, idx);
  const value = line.slice(idx + 1);
  const parts = head.split(";");
  const name = parts[0].toUpperCase();
  const params = {};
  for (const p of parts.slice(1)) {
    const eq = p.indexOf("=");
    if (eq > 0) params[p.slice(0, eq).toUpperCase()] = p.slice(eq + 1);
  }
  return { name, params, value };
}

function parseEvents(icsText) {
  const blocks = [];
  let current = null;
  const unfolded = [];
  for (const raw of String(icsText).replace(/\r\n/g, "\n").split("\n")) {
    if (/^[ \t]/.test(raw) && unfolded.length) unfolded[unfolded.length - 1] += raw.slice(1);
    else unfolded.push(raw);
  }
  for (const raw of unfolded) {
    const line = raw.trim();
    if (!line) continue;
    if (line === "BEGIN:VEVENT") { current = {}; continue; }
    if (line === "END:VEVENT") { if (current) { blocks.push(current); current = null; } continue; }
    if (current) {
      const { name, params, value } = splitValue(line);
      if (["DTSTART", "DTEND", "DTSTAMP", "SUMMARY", "RRULE", "EXDATE", "UID", "DESCRIPTION", "LOCATION"].includes(name)) {
        if (name === "EXDATE") (current.EXDATE ??= []).push({ params, value });
        else current[name] = { params, value };
      }
    }
  }

  const events = [];
  for (const blk of blocks) {
    if (!blk.DTSTART) continue;
    const tzid = blk.DTSTART.params.TZID || "";
    const { date: startDt, allDay } = parseDt(blk.DTSTART.value, tzid);
    if (!startDt) continue;

    let durMs = 3600000; // default 1h
    if (blk.DTEND) {
      const end = parseDt(blk.DTEND.value, blk.DTEND.params.TZID || tzid).date;
      if (end) durMs = Math.max(60000, end.getTime() - startDt.getTime());
    } else if (blk.DTSTAMP && allDay) {
      durMs = DAY_MS;
    }

    let title = "";
    if (blk.SUMMARY) title = blk.SUMMARY.value;
    title = title.replace(/\\,/g, ",").replace(/\\;/g, ";").replace(/\\\\/g, "\\");

    let occs = [startDt];
    if (blk.RRULE) {
      const rule = parseRule(blk.RRULE.value, tzid);
      occs = expandRule(rule, startDt, tzid);
    }

    const exdates = new Set();
    if (blk.EXDATE) {
      for (const entry of blk.EXDATE) {
        const exTzid = entry.params.TZID || tzid;
        for (const part of entry.value.split(",")) {
          const d = parseDt(part, exTzid).date;
          if (d) exdates.add(d.getTime());
        }
      }
    }

    for (const occ of occs) {
      const d = occ.getTime();
      if (d < WINDOW_START || d > WINDOW_END) continue;
      if (exdates.has(d)) continue;
      if (allDay) {
        const dayCount = Math.max(1, Math.round(durMs / DAY_MS));
        for (let i = 0; i < dayCount; i++) {
          const dd = d + i * DAY_MS;
          if (dd < WINDOW_START || dd > WINDOW_END) continue;
          events.push({ date: dd, s: "", e: "", t: title, a: true });
        }
      } else {
        const s = fmtLocal(occ, "HH:MM");
        const end = new Date(occ.getTime() + durMs);
        const e = end.toDateString() === occ.toDateString() ? fmtLocal(end, "HH:MM") : "";
        events.push({ date: d, s, e, t: title, a: false });
      }
    }
  }

  const out = {};
  for (const ev of events) {
    const key = fmtLocal(new Date(ev.date), "YYYY-MM-DD");
    (out[key] = out[key] || []).push({ s: ev.s, e: ev.e, t: ev.t, a: ev.a });
  }
  for (const k of Object.keys(out)) {
    out[k].sort((x, y) => (x.a === y.a ? (x.s < y.s ? -1 : x.s > y.s ? 1 : 0) : (x.a ? 1 : -1)));
  }
  return out;
}

function fmtLocal(d, fmt) {
  const p = (n, w = 2) => String(n).padStart(w, "0");
  if (fmt === "YYYY-MM-DD") return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
  if (fmt === "HH:MM") return `${p(d.getHours())}:${p(d.getMinutes())}`;
  return "";
}

function main() {
  const icsPath = join(homedir(), ".cache/kmdot/calendar.ics");
  let text = "";
  try {
    text = readFileSync(icsPath, "utf8");
  } catch (e) {
    text = "";
  }
  try {
    const events = parseEvents(text);
    process.stdout.write(JSON.stringify({ ok: true, events }));
  } catch (err) {
    process.stdout.write(JSON.stringify({ ok: false, error: String(err && err.message || err), events: {} }));
  }
}

main();
