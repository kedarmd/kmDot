import QtQuick

// PROTOTYPE (wayfinder map "Omarchy plugin support", ticket "Themed pilot
// plugin proof in kmdot bar"): throwaway Tier-1/Tier-2 shell surface for the
// pilot. Tier-1 emulated: updateEntryInline (in-memory live-patch + log, no
// shell.json write), summon/hide/toggle/isPluginOpen (routed to the host
// widget). Tier-2 stubbed: firstPartyServiceFor -> null + stderr. The host
// assigns one instance per plugin to its PluginBarApi facade's `shell` prop.
// NOT production code.
QtObject {
  id: root

  required property string pluginId
  property var host: null // PluginHost: owns settings + the Loader item

  function updateEntryInline(id, entry) {
    if (host) host.applyEntryInline(entry)
    console.log("[plugin-shim:prototype] updateEntryInline", id, "(in-memory only, no shell.json write)")
  }

  function summon(id) {
    if (host) host.summonPanel()
  }

  function hide(id) {
    if (host) host.closePanel()
  }

  function toggle(id) {
    if (host) host.togglePanel()
  }

  function isPluginOpen(id) {
    return host ? host.pluginOpened : false
  }

  function firstPartyServiceFor(name) {
    console.warn("[plugin-shim:prototype] firstPartyServiceFor(" + name + ") stubbed -> null")
    return null
  }
}
