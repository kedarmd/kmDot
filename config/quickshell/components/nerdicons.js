.pragma library

// Semantic names for kmDot UI symbols, mapped to Material Design Icons glyphs
// bundled in JetBrainsMono Nerd Font Propo. Keep interface glyphs in one icon
// family so their stroke weight and visual scale stay consistent.
var glyphs = {
  search: codePoint(0xF0349), close: codePoint(0xF0156),
  chevron: codePoint(0xF0142), back: codePoint(0xF0141),
  terminal: codePoint(0xF018D), display: codePoint(0xF0379),
  menu: codePoint(0xF035C),
  monitor: codePoint(0xF0379), apps: codePoint(0xF003B),
  clipboard: codePoint(0xF0147), copy: codePoint(0xF018F),
  music: codePoint(0xF0387), power: codePoint(0xF0425),
  wifi: codePoint(0xF05A9), "wifi-on": codePoint(0xF05A9),
  "wifi-connected": codePoint(0xF16BD),
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
  lock: codePoint(0xF033E), moon: codePoint(0xF0594),
  logout: codePoint(0xF0343), refresh: codePoint(0xF0450),
  keyboard: codePoint(0xF030C), mic: codePoint(0xF036C),
  "mic-off": codePoint(0xF036D), bell: codePoint(0xF009A),
  "bell-off": codePoint(0xF009B), server: codePoint(0xF048B),
  globe: codePoint(0xF059F), folder: codePoint(0xF024B),
  play: codePoint(0xF040A), "play-circle-outline": codePoint(0xF040D), pause: codePoint(0xF03E4),
  plus: codePoint(0xF0415), trash: codePoint(0xF01B4),
  check: codePoint(0xF012C), calendar: codePoint(0xF00ED),
  chart: codePoint(0xF012A), palette: codePoint(0xF03D8),
  headphones: codePoint(0xF02CB), audio: codePoint(0xF057E),
  "audio-medium": codePoint(0xF0580), "audio-low": codePoint(0xF057F),
  "audio-off": codePoint(0xF0581), sun: codePoint(0xF0599),
  camera: codePoint(0xF0100), mouse: codePoint(0xF037D),
  info: codePoint(0xF02FC), skip: codePoint(0xF04AD),
  "chevron-down": codePoint(0xF0140), "lock-open": codePoint(0xF033F),
  "eye-off": codePoint(0xF0209), eye: codePoint(0xF0208),
  loading: codePoint(0xF0772), code: codePoint(0xF0174),
  tune: codePoint(0xF062E), undo: codePoint(0xF054C),
  "skip-previous": codePoint(0xF04AE), calculator: codePoint(0xF00EC),
  history: codePoint(0xF02DA), cog: codePoint(0xF0493),
  arrow: codePoint(0xF004D), "open-in-new": codePoint(0xF03CC),
  star: codePoint(0xF04CE), "star-outline": codePoint(0xF04D2),
  "arrow-up": codePoint(0xF005D), "arrow-down": codePoint(0xF0045),
  "arrow-right": codePoint(0xF0054),
  restore: codePoint(0xF099B), cancel: codePoint(0xF073A),
  "format-text": codePoint(0xF0284), block: codePoint(0xF00AD),
  cellphone: codePoint(0xF011C), laptop: codePoint(0xF0322),
  television: codePoint(0xF0502), image: codePoint(0xF02E9),
  tag: codePoint(0xF04F9), warning: codePoint(0xF0026),
  leaf: codePoint(0xF032A)
};

// Normalize legacy Font Awesome PUA call sites to their Material Design
// counterparts. R1Icon applies this to raw glyphs while older QML call sites
// are migrated gradually; unknown glyphs pass through unchanged.
var aliases = {
  "\uf002": glyphs.search, "\uf00d": glyphs.close,
  "\uf054": glyphs.chevron, "\uf053": glyphs.back,
  "\uf120": glyphs.terminal, "\uf108": glyphs.display,
  "\uf00a": glyphs.apps,
  "\uf0ea": glyphs.clipboard, "\uf0c5": glyphs.copy,
  "\uf001": glyphs.music, "\uf011": glyphs.power,
  "\uf023": glyphs.lock, "\uf186": glyphs.moon,
  "\uf08b": glyphs.logout, "\uf021": glyphs.refresh,
  "\uf11c": glyphs.keyboard, "\uf130": glyphs.mic,
  "\uf131": glyphs["mic-off"], "\uf0f3": glyphs.bell,
  "\uf1f6": glyphs["bell-off"], "\uf233": glyphs.server,
  "\uf0ac": glyphs.globe, "\uf07b": glyphs.folder,
  "\uf04b": glyphs.play, "\uf04c": glyphs.pause,
  "\uf067": glyphs.plus, "\uf1f8": glyphs.trash,
  "\uf00c": glyphs.check, "\uf073": glyphs.calendar,
  "\uf080": glyphs.chart, "\uf53f": glyphs.palette,
  "\uf025": glyphs.headphones, "\uf028": glyphs.audio,
  "\uf027": glyphs["audio-low"], "\uf026": glyphs["audio-off"],
  "\uf185": glyphs.sun, "\uf030": glyphs.camera,
  "\uf245": glyphs.mouse, "\uf05a": glyphs.info,
  "\uf051": glyphs.skip, "\uf105": glyphs.chevron,
  "\uf078": glyphs["chevron-down"], "\uf107": glyphs["chevron-down"],
  "\uf110": glyphs.loading, "\uf121": glyphs.code,
  "\uf1de": glyphs.tune, "\uf09c": glyphs["lock-open"],
  "\uf06e": glyphs.eye, "\uf070": glyphs["eye-off"],
  "\uf1da": glyphs.history, "\uf1ec": glyphs.calculator,
  "\uf013": glyphs.cog, "\uf060": glyphs.arrow,
  "\uf1a0": glyphs.globe,
  "\uf1eb": glyphs.wifi, "\uf293": glyphs.bluetooth,
  "\uf0e2": glyphs.restore, "\uf35d": glyphs["open-in-new"],
  "\uf005": glyphs.star, "\uf006": glyphs["star-outline"],
  "\uf063": glyphs["arrow-down"], "\uf062": glyphs["arrow-up"],
  "\uf05e": glyphs.block, "\uf031": glyphs["format-text"],
  "\ue900": glyphs.apps,
  "\uf10b": glyphs.cellphone, "\uf109": glyphs.laptop,
  "\uf26c": glyphs.television,
  "\uf009": glyphs.menu,
  "\uf048": glyphs["skip-previous"], "\uf02b": glyphs.tag,
  "\uf03e": glyphs.image,
  "\uf06c": glyphs.leaf, "\uf071": glyphs.warning,
  "\uf1f6": glyphs["bell-off"], "\uf1fc": glyphs.palette,
  "\uf240": glyphs["battery-100"], "\uf241": glyphs["battery-80"],
  "\uf242": glyphs["battery-60"], "\uf243": glyphs["battery-40"],
  "\uf244": glyphs["battery-20"],
  "": glyphs.cog, "": glyphs.arrow,
  "": codePoint(0xF04F9), "": codePoint(0xF0026)
};

function codePoint(value) {
  if (value <= 0xFFFF) return String.fromCharCode(value);
  value -= 0x10000;
  return String.fromCharCode(0xD800 + (value >> 10), 0xDC00 + (value & 0x3FF));
}

function glyph(name) {
  return glyphs[name] || "";
}

function normalizeGlyph(value) {
  return aliases[value] || value;
}
