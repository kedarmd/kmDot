import QtQuick
import qs
import "../components"

// Bar-module view over the DisplayState singleton (issue #49 owns state):
// zero Processes here, all detection/polling/apply lives in DisplayState.
BarModule {
  id: root
  sock: "kmdot-display"

  iconName: "display"
  iconForeground: Colors.primary_alt
  clickable: DisplayState.barHasBacklight
  dimmed: !DisplayState.barHasBacklight

  tooltipText: {
    if (!DisplayState.barHasBacklight) return "Display (no backlight)"
    return "Brightness: " + DisplayState.barPercent + "%"
  }

  onWheeled: wheel => {
    if (DisplayState.barHasBacklight) DisplayState.nudgeBar(wheel.angleDelta.y > 0 ? 1 : -1)
  }
}
