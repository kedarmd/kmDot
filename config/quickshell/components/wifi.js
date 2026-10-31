// Pure wifi helpers (issue #61): stateless string/parse/sort functions only.
// No Process, no timers, no Qt/QML dependencies — node-runnable for tests.
function toStr(v) {
  if (v === undefined || v === null) return ""
  if (typeof v === "string") return v
  if (Array.isArray(v)) return v.join(" ")
  return String(v)
}

function shellQuote(s) {
  return "'" + toStr(s).replace(/'/g, "'\\''") + "'"
}

function decodeNmcli(s) {
  return toStr(s).replace(/\\([\\:sn])/g, function(_, code) {
    if (code === ":") return ":"
    if (code === "s") return " "
    if (code === "n") return "\n"
    return "\\"
  })
}

function isOpen(security) {
  const sec = toStr(security)
  return !sec || sec === "--" || sec === "NONE" || sec === "OPEN"
}

function signalGlyph(signal) {
  const s = Number(signal) || 0
  if (s >= 75) return "████"
  if (s >= 50) return "██▆▁"
  if (s >= 25) return "█▄▁▁"
  return "▁▁▁▁"
}

// Right-anchored colon parse: SSIDs may contain colons (nmcli -t escapes them
// as \: but decode happens after the split), so ACTIVE is the first field and
// SIGNAL/SECURITY are the last two; everything between is the SSID.
function parseScanLine(line) {
  const parts = toStr(line).split(":")
  if (parts.length < 4) return null
  const ssid = decodeNmcli(parts.slice(1, parts.length - 2).join(":"))
  if (!ssid) return null
  const security = parts[parts.length - 1]
  return {
    ssid: ssid,
    active: parts[0] === "yes",
    signal: parseInt(parts[parts.length - 2], 10) || 0,
    security: security,
    open: isOpen(security)
  }
}

function parseSavedLine(line) {
  const prefix = "802-11-wireless:"
  const value = toStr(line)
  return value.startsWith(prefix) ? decodeNmcli(value.slice(prefix.length)) : ""
}

function parseActiveLine(line) {
  return parseSavedLine(line)
}

function sortNetworks(list) {
  if (!list) return []
  return list.slice().sort(function(a, b) {
    return ((b.active ? 1 : 0) - (a.active ? 1 : 0)) || (b.signal - a.signal)
  })
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    toStr, shellQuote, decodeNmcli, isOpen, signalGlyph,
    parseScanLine, parseSavedLine, parseActiveLine, sortNetworks
  }
}
