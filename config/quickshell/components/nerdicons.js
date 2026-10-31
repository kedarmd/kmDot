.pragma library

// Semantic names for kmDot UI symbols, mapped to glyphs in JetBrainsMono
// Nerd Font Propo. Keep this list limited to icons used by the shell UI.
var glyphs = {
  search: "\uf002", close: "\uf00d", chevron: "\uf054", back: "\uf053",
  terminal: "\uf120", display: "\uf108", apps: "\uf00a", clipboard: "\uf0ea",
  copy: "\uf0c5", music: "\uf001", power: "\uf011",
  wifi: codePoint(0xF05A9), "wifi-on": codePoint(0xF05A9),
  "wifi-connected-high": codePoint(0xF0928),
  "wifi-connected-medium": codePoint(0xF0925),
  "wifi-connected-low": codePoint(0xF091F),
  "wifi-off": codePoint(0xF05AA), "wifi-disabled": codePoint(0xF05AA),
  ethernet: codePoint(0xF0200), bluetooth: codePoint(0xF00AF),
  "bluetooth-on": codePoint(0xF00AF), "bluetooth-connected": codePoint(0xF00B1),
  "bluetooth-off": codePoint(0xF00B2),
  battery: codePoint(0xF0079), "battery-100": codePoint(0xF0079),
  "battery-10": codePoint(0xF007A), "battery-20": codePoint(0xF007B),
  "battery-30": codePoint(0xF007C), "battery-40": codePoint(0xF007D),
  "battery-50": codePoint(0xF007E), "battery-60": codePoint(0xF007F),
  "battery-70": codePoint(0xF0080), "battery-80": codePoint(0xF0081),
  "battery-90": codePoint(0xF0082), "battery-empty": codePoint(0xF008E),
  lock: "\uf023", moon: "\uf186",
  logout: "\uf08b", refresh: "\uf021", keyboard: "\uf11c", mic: "\uf130",
  "mic-off": "\uf131", bell: "\uf0f3", "bell-off": "\uf1f6", server: "\uf233",
  globe: "\uf0ac", folder: "\uf07b", play: "\uf04b", pause: "\uf04c",
  plus: "\uf067", trash: "\uf1f8", check: "\uf00c", calendar: "\uf073",
  chart: "\uf080", palette: "\uf53f", headphones: "\uf025", audio: "\uf028",
  "audio-medium": "\uf028", "audio-low": "\uf027", "audio-off": "\uf026",
  sun: "\uf185", camera: "\uf030", mouse: codePoint(0xEFBA),
  info: "\uf05a", skip: "\uf051"
};

function codePoint(value) {
  if (value <= 0xFFFF) return String.fromCharCode(value);
  value -= 0x10000;
  return String.fromCharCode(0xD800 + (value >> 10), 0xDC00 + (value & 0x3FF));
}

function glyph(name) {
  return glyphs[name] || "";
}
