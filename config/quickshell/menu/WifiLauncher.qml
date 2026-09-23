import QtQuick
import Quickshell
import Quickshell.Io
import "../components"
import "../components/wifi.js" as WifiJs
import qs

LauncherBase {
  id: root

  sockName: "kmdot-wifi"
  title: "Wi-Fi"
  footerHint: "↑↓ navigate · ⏎ connect · tab toggle · esc close"
  countShown: false
  loadingText: "Scanning for networks..."
  // Items decide whether to close themselves — the password flow keeps the launcher open.
  closeOnActivate: false

  // Thin adapter over the Wifi singleton (issue #61): the pool derives from
  // the shared networks list; this view keeps pool derivation, activate
  // intent, password promptMode wiring, and the footer pill only.
  // promptSsid tracks the secured network currently in the password flow
  // across submits and re-prompts (survives startPrompt resets).
  property string promptSsid: ""

  function sigGlyph(sig) { return WifiJs.signalGlyph(sig) }

  function refreshItems() {
    root.promptSsid = ""
    Wifi.errorText = ""
    Wifi.scan()
    root.buildPool()
  }

  function syncFooter() {
    root.footerActionGlyph = Wifi.enabled ? "" : ""
    root.footerActionText = Wifi.enabled ? "Wi-Fi On" : "Wi-Fi Off"
    root.footerActionActive = Wifi.enabled
  }

  function buildPool() {
    const items = []
    for (const n of Wifi.networks) {
      items.push({
        label: n.ssid,
        subtitle: (n.active ? "active · " : "") + (n.open ? "Open" : n.security) + " · " + root.sigGlyph(n.signal) + " " + n.signal + "%",
        glyph: "",
        ssid: n.ssid,
        active: !!n.active,
        saved: !!(n.saved || Wifi.isSaved(n.ssid)),
        open: !!n.open,
        signal: n.signal,
        security: n.security
      })
    }
    // Wifi.networks arrives sorted from the store; keep that order.
    root.loading = Wifi.scanning && items.length === 0
    root.emptyText = !Wifi.enabled ? "Wi-Fi is turned off" : "No networks found"
    root.syncFooter()
    root.pool = items
  }

  function findNet(ssid) {
    for (const it of root.pool) {
      if (it.ssid === ssid) return { ssid: it.ssid, active: false, open: !!it.open, saved: !!it.saved, security: it.security }
    }
    return { ssid: ssid, active: false, open: false, saved: Wifi.isSaved(ssid) }
  }

  function connectTo(item) {
    if (item.active) {
      root.closeLauncher()
      Wifi.disconnect({ ssid: item.ssid })
      return
    }
    if (item.saved || item.open) {
      root.closeLauncher()
      Wifi.connect({ ssid: item.ssid, active: false, open: !!item.open, saved: !!item.saved, security: item.security })
      return
    }
    root.promptSsid = item.ssid
    root.startPrompt("Password for " + item.ssid)
  }

  onActivated: function(item) {
    root.connectTo(item)
  }

  onFooterActionClicked: {
    // Keep the surface open across the toggle; the store rescans and the
    // pool rebuilds through the Connections below.
    Wifi.toggleRadio()
  }

  onPromptSubmitted: function(text) {
    const ssid = root.promptSsid
    if (!ssid || !text) return
    if (!Wifi.connect(root.findNet(ssid), text)) {
      root.startPrompt("Password for " + ssid, "Connection failed")
      return
    }
    // Success settles through onBusySsidChanged (closes); a failure
    // re-prompts through onErrorTextChanged below.
  }

  // Failure UI stays view-shaped over the shared store errorText: a failed
  // password connect re-prompts with the error instead of closing.
  // Order is load-bearing: the store sets errorText before clearing
  // busySsid, so a failure re-prompts (promptMode=true) before the busy
  // handler runs, and only the success path still has promptMode=false.
  Connections {
    target: Wifi
    function onNetworksChanged() { root.buildPool() }
    function onScanningChanged() { root.buildPool() }
    function onEnabledChanged() { root.buildPool() }
    function onErrorTextChanged() {
      if (Wifi.errorText === "" || root.promptSsid === "" || !root.opened) return
      const ssid = root.promptSsid
      const err = Wifi.errorText
      Wifi.errorText = ""
      root.startPrompt("Password for " + ssid,
        "Connection failed" + (err ? ": " + err : ""))
    }
    function onBusySsidChanged() {
      if (Wifi.busySsid !== "" || root.promptSsid === "" || !root.opened) return
      if (!root.promptMode && Wifi.errorText === "") {
        root.closeLauncher()
        root.promptSsid = ""
      }
    }
  }
}
