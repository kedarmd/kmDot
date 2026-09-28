pragma Singleton
import QtQuick
import qs

// PROTOTYPE (wayfinder map "Omarchy plugin support", ticket "Themed pilot
// plugin proof in kmdot bar"): throwaway Tier-1 Style shim. Implements the
// exact structural surface the vendored clock + Ui components call
// (space/font/bar/spacing/cornerRadius/duration + state color/fill/border
// helpers), with kmdot-fed values. State helpers approximate Omarchy's
// TOML-driven tokens as accent-tinted blends that stay legible on dark
// fills; the real spec will define canonical mappings. NOT production code.
QtObject {
  id: root

  readonly property int cornerRadius: 12
  readonly property int gapsOut: 10

  // Vendored Border.qml reads per-state/per-side overrides here; empty means
  // every spec resolves to its call-site fallback (flat kmdot-fed values).
  readonly property var styleOverrides: ({})

  readonly property var font: QtObject {
    readonly property string family: "JetBrainsMono Nerd Font Propo"
    readonly property real body: 15
    readonly property real bodySmall: 12
    readonly property real caption: 11
    readonly property real icon: 15
  }

  readonly property var bar: QtObject {
    readonly property int iconSlot: 22
    readonly property int sizeHorizontal: 30
  }

  readonly property var spacing: QtObject {
    readonly property real hairline: 1
    readonly property real controlPaddingX: 8
    readonly property real controlPaddingY: 6
    readonly property real sm: 4
    readonly property real popupPadding: 16
    readonly property real inputPaddingY: 6
  }

  // Omarchy scales spacing/typography by theme; the prototype is 1:1.
  function space(n) { return Math.round(Number(n) || 0) }
  function spaceReal(n) { return Number(n) || 0 }
  function duration(ms) { return Number(ms) || 0 }

  // State colors: idle chrome stays foreground, interactive states pick up
  // the kmdot primary accent (all light-on-dark, never dark text).
  function normalStateColor(foreground, accent, urgent) { return foreground }
  function hoverStateColor(foreground, accent, urgent) { return accent }
  function selectedStateColor(foreground, accent, urgent) { return accent }
  function focusStateColor(foreground, accent, urgent) { return accent }

  function hoverFillFor(foreground, accent) { return Qt.rgba(accent.r, accent.g, accent.b, 0.16) }
  function selectionFillFor(foreground, accent) { return Qt.rgba(accent.r, accent.g, accent.b, 0.22) }
  function focusFillFor(foreground, accent) { return Qt.rgba(accent.r, accent.g, accent.b, 0.22) }
  function controlFill(focused, hot, foreground, accent) {
    if (focused) return focusFillFor(foreground, accent)
    if (hot) return hoverFillFor(foreground, accent)
    return Colors.surface_alt
  }

  function normalBorderFor(foreground, accent) { return Colors.border }

  readonly property real normalBorderWidth: 1
  readonly property real normalBorderAlpha: 1
  readonly property real hoverBorderWidth: 1
  readonly property real hoverBorderAlpha: 1
  readonly property real selectedBorderWidth: 1
  readonly property real selectedBorderAlpha: 1
  readonly property real focusBorderWidth: 1
  readonly property real focusBorderAlpha: 1
}
