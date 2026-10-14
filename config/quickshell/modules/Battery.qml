import QtQuick
import Quickshell.Services.UPower
import qs
import "../components"

BarModule {
  id: root
  sock: "kmdot-battery"

  readonly property var battery: UPower.displayDevice
  function batteryPercent(dev) {
    if (!dev) return 0
    var p = dev.percentage
    if (p <= 1.5) p = p * 100
    return Math.max(0, Math.min(100, Math.round(p)))
  }

  readonly property int capacity: battery && battery.isPresent ? batteryPercent(battery) : 0
  readonly property bool charging: battery && (battery.state === UPowerDeviceState.Charging
    || battery.state === UPowerDeviceState.PendingCharge
    || battery.state === UPowerDeviceState.FullyCharged)
  readonly property bool discharging: battery && battery.state === UPowerDeviceState.Discharging
  readonly property string statusText: battery
    ? (battery.state === UPowerDeviceState.FullyCharged ? "Full" : UPowerDeviceState.toString(battery.state))
    : "Unknown"
  readonly property string profileText: {
    if (PowerProfiles.profile === PowerProfile.PowerSaver) return "power-saver"
    if (PowerProfiles.profile === PowerProfile.Balanced) return "balanced"
    if (PowerProfiles.profile === PowerProfile.Performance) return "performance"
    return "unknown"
  }

  tooltipText: {
    var t = "Battery: " + capacity + "% (" + statusText + ")"
    if (discharging && battery && battery.timeToEmpty > 0) {
      t += "\nTime remaining: " + formatTime(battery.timeToEmpty)
    }
    t += "\nPower profile: " + profileText
    return t
  }

  function formatTime(seconds) {
    if (seconds >= 3600) return (seconds / 3600).toFixed(1) + " hours"
    return Math.round(seconds / 60) + " minutes"
  }

  glyph: ""
  text: capacity + "%"
  iconName: {
    if (capacity <= 20) return "battery-empty"
    if (capacity <= 40) return "battery-low"
    if (capacity <= 60) return "battery-medium"
    return "battery"
  }
  // Keep the charging state visible in the bar, not only inside the popup.
  // The icon encodes charge level only, so charging is carried by the
  // success-tonal pill plus bold percentage in this same compact module.
  active: root.charging
  foreground: root.capacity <= 15 ? Colors.error : root.capacity <= 30 ? Colors.warning : Colors.text
  fill: root.charging ? Tokens.successContainer
      : root.capacity <= 15 ? Tokens.errorContainer
      : Tokens.warningContainer
  on_color: root.charging ? Tokens.on_success_container
         : root.capacity <= 15 ? Tokens.on_error_container
         : Tokens.on_warning_container
}
