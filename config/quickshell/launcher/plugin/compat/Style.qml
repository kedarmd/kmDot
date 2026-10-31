pragma Singleton
import QtQuick
import Quickshell

QtObject {
  readonly property bool reducedMotion: Quickshell.env("KMDOT_REDUCED_MOTION") === "1"
  function space(value) { return value }
  readonly property int cornerRadius: 12
  readonly property int gapsOut: 16
  readonly property var spacing: ({ hairline: 1 })
  readonly property string iconFamily: "JetBrainsMono Nerd Font Propo"
  readonly property var font: ({ menuFamily: Quickshell.env("KMDOT_LAUNCHER_FONT_FAMILY") || "Adwaita Sans", heading: 17, body: 14, bodySmall: 12, caption: 11, title: 15 })
}
