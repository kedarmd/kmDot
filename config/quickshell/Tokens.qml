pragma Singleton
import QtQuick
import Quickshell
import qs

// Semantic aliases from the complete active theme. No palette defaults or color synthesis.
Singleton {
  // Opt-in accessibility setting applied to shell, panel, and launcher motion.
  readonly property bool reducedMotion: Quickshell.env("KMDOT_REDUCED_MOTION") === "1"

  // Shared motion timings for the keyboard-driven shell.
  readonly property int motionFast: reducedMotion ? 0 : 120
  readonly property int motionStandard: reducedMotion ? 0 : 180
  readonly property int motionEmphasized: reducedMotion ? 0 : 220
  readonly property int motionEasing: Easing.OutCubic
  readonly property int meterMotion: reducedMotion ? 0 : 80
  readonly property int busyRotation: 1000

  readonly property int notificationMotion: motionStandard
  readonly property int notificationDismissMotion: motionFast

  // Shared outline weight for major cards, panels, and popup surfaces.
  readonly property real surfaceBorderWidth: 1.5

  // ---- surfaces (tonal elevation) ----
  readonly property color surfaceContainerLowest: Colors.base
  readonly property color surfaceContainerLow: Colors.surface
  readonly property color surfaceContainer: Colors.surface_alt
  readonly property color surfaceContainerHigh: Colors.surface_high
  readonly property color surfaceContainerHighest: Colors.surface_highest

  // ---- semantics ----
  readonly property color on_surface: Colors.text
  readonly property color on_surface_variant: Colors.text_alt
  readonly property color outline: Colors.muted
  readonly property color outlineVariant: Colors.outline_variant
  readonly property color divider: Colors.divider

  readonly property color mutedText: Colors.muted_text
  readonly property color errorText: Colors.error_text

  // ---- primary ----
  // NOTE: property names must NEVER match `on` + UppERCASE (e.g. onPrimary) —
  // QML parses those as signal handlers, so the property silently never exists
  // and every consumer falls back to black text. Hence snake_case on_*.
  readonly property color primary: Colors.primary
  readonly property color pill: Colors.pill
  readonly property color on_pill: Colors.on_pill
  readonly property color on_primary: Colors.on_primary
  readonly property color primaryContainer: Colors.primary_container
  readonly property color on_primary_container: Colors.on_primary_container

  readonly property color secondary: Colors.primary_alt
  readonly property color tertiary: Colors.accent
  readonly property color success: Colors.success
  readonly property color successContainer: Colors.success_container
  readonly property color on_success_container: Colors.on_success_container
  readonly property color warning: Colors.warning
  readonly property color warningContainer: Colors.warning_container
  readonly property color on_warning_container: Colors.on_warning_container
  readonly property color error: Colors.error
  readonly property color errorContainer: Colors.error_container
  readonly property color on_error_container: Colors.on_error_container
  readonly property color scrim: Colors.scrim
}
