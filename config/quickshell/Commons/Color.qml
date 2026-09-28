pragma Singleton
import QtQuick
import qs

// PROTOTYPE (wayfinder map "Omarchy plugin support", ticket "Themed pilot
// plugin proof in kmdot bar"): throwaway Tier-1 Color shim. Feeds the
// vendored Omarchy Ui components from kmdot Colors so the pilot renders in
// the active kmdot theme (all 5 via the normal Colors.qml regen + restart).
// Approximates Omarchy's TOML-driven roles; the real spec will define the
// full theme bridge. NOT production code.
QtObject {
  id: root

  // Empty: Border.qml resolves every value() lookup to its passed fallback,
  // so all border specs come from the call-site fallbacks below.
  readonly property var shellValues: ({})

  readonly property color foreground: Colors.text
  readonly property color background: Colors.surface
  readonly property color accent: Colors.primary
  readonly property color urgent: Colors.error
  readonly property color muted: Colors.muted

  readonly property var tooltip: QtObject {
    readonly property color text: Colors.text
    readonly property color background: Colors.surface_high
    readonly property color border: Colors.border
  }

  readonly property var popups: QtObject {
    readonly property color background: Colors.surface_high
    readonly property color border: Colors.border
  }
}
