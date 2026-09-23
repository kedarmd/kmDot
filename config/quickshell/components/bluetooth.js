// Pure bluetooth helpers (issue #61): stateless mapping/sort functions only.
// No Process, no timers, no Qt/QML dependencies — node-runnable for tests.
function toStr(v) {
  if (v === undefined || v === null) return ""
  if (typeof v === "string") return v
  if (Array.isArray(v)) return v.join(" ")
  if (typeof v === "object" && typeof v.join === "function") return v.join(" ")
  return String(v)
}

// Single device-glyph mapping (superset of the dropdown + launcher copies:
// launcher additionally covered input-tablet, audio-card, tv).
function deviceGlyph(icon) {
  switch (toStr(icon).toLowerCase()) {
    case "input-keyboard": return ""
    case "input-mouse":
    case "input-tablet": return ""
    case "audio-headset":
    case "audio-headphones":
    case "audio-card": return ""
    case "phone":
    case "smartphone": return ""
    case "computer":
    case "laptop": return ""
    case "video-display":
    case "tv": return ""
    default: return ""
  }
}

function sortDevices(list) {
  if (!list) return []
  return list.slice().sort(function(a, b) {
    return ((b.connected ? 1 : 0) - (a.connected ? 1 : 0))
      || ((b.paired ? 1 : 0) - (a.paired ? 1 : 0))
      || String(a.name || "").localeCompare(String(b.name || ""))
  })
}

function batteryLabel(batteryAvailable, batteryPercent) {
  if (!batteryAvailable) return ""
  const pct = Math.round(Number(batteryPercent))
  if (!isFinite(pct) || pct < 0) return ""
  return " · " + pct + "%"
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = { toStr, deviceGlyph, sortDevices, batteryLabel }
}
