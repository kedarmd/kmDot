// Shared server-mode status parser (single source of truth for the
// `server-mode.sh status` key=value lines). Both the bar module and the
// dropdown parse through here so neither drops fields the other needs.

function parseServerStatus(text) {
  const out = { mode: "off", inhibitor: "inactive", tailscale: "inactive", tailscaleIp: "", jellyfin: "inactive" }
  for (const line of String(text).split("\n")) {
    const ln = line.trim()
    if (!ln) continue
    const i = ln.indexOf("=")
    if (i < 0) continue
    const k = ln.slice(0, i).trim()
    const v = ln.slice(i + 1).trim()
    if (k === "mode") out.mode = v
    else if (k === "inhibitor") out.inhibitor = v
    else if (k === "tailscale") out.tailscale = v
    else if (k === "tailscale_ip") out.tailscaleIp = v
    else if (k === "jellyfin") out.jellyfin = v
  }
  return out
}
