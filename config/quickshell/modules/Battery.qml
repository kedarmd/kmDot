import QtQuick
import Quickshell.Io
import Quickshell.Services.UPower
import qs
import "../components"

BarModule {
  id: root
  sock: "kmdot-battery"
  smoothIconColor: true

  readonly property var battery: UPower.displayDevice
  function batteryPercent(dev) {
    if (!dev) return 0
    var p = dev.percentage
    if (p <= 1.5) p = p * 100
    return Math.max(0, Math.min(100, Math.round(p)))
  }

  readonly property int capacity: battery && battery.isPresent ? batteryPercent(battery) : 0
  // Battery state can remain FullyCharged after unplugging, and UPower's
  // adapter cache can lag. Read the kernel's online flag for the power marker.
  // -1 means no readable adapter; retain the native service as a fallback.
  property int adapterOnline: -1
  readonly property bool charging: battery && battery.isPresent
    && (root.adapterOnline >= 0 ? root.adapterOnline === 1 : !UPower.onBattery)

  Process {
    id: adapterPoll
    command: ["bash", "-c", "found=0; for supply in /sys/class/power_supply/*; do [[ -r \"$supply/online\" && -r \"$supply/type\" ]] || continue; read -r type < \"$supply/type\"; [[ $type == Battery ]] && continue; read -r online < \"$supply/online\"; [[ $online == 0 || $online == 1 ]] || continue; found=1; if [[ $online == 1 ]]; then printf '1\\n'; exit; fi; done; if (( found )); then printf '0\\n'; else printf '%s\\n' -1; fi"]
    stdout: SplitParser {
      onRead: data => {
        var value = Number(data.trim())
        if (value === -1 || value === 0 || value === 1) root.adapterOnline = value
      }
    }
    onExited: (exitCode, exitStatus) => {
      if (exitCode !== 0) root.adapterOnline = -1
    }
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      if (!adapterPoll.running) adapterPoll.running = true
    }
  }
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
    if (capacity <= 0) return "battery-empty"
    // The Nerd Font battery family has decile glyphs; use the nearest level.
    var level = Math.min(100, Math.max(10, Math.round(capacity / 10) * 10))
    return "battery-" + level
  }
  // Power status colors the icon; the percentage keeps its level color.
  iconForeground: root.charging ? Colors.success : root.foreground
  foreground: root.capacity <= 15 ? Colors.error : root.capacity <= 30 ? Colors.warning : Colors.text
}
