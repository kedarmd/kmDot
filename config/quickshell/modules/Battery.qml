import QtQuick
import Quickshell.Services.UPower
import qs

Item {
  id: root
  implicitHeight: 30
  width: label.implicitWidth + 20
  required property var tooltip

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
  readonly property string tooltipText: {
    var t = "Battery: " + capacity + "% (" + statusText + ")"
    if (discharging && battery && battery.timeToEmpty > 0) {
      t += "\nTime remaining: " + formatTime(battery.timeToEmpty)
    }
    t += "\nPower profile: " + profileText
    return t
  }

  readonly property string icon: {
    if (capacity <= 20) return ""
    if (capacity <= 40) return ""
    if (capacity <= 60) return ""
    if (capacity <= 80) return ""
    return ""
  }
  readonly property string text: charging
    ? " " + capacity + "%"
    : icon + " " + capacity + "%"

  function formatTime(seconds) {
    if (seconds >= 3600) return (seconds / 3600).toFixed(1) + " hours"
    return Math.round(seconds / 60) + " minutes"
  }

  function cycleProfile() {
    if (PowerProfiles.profile === PowerProfile.PowerSaver) {
      PowerProfiles.profile = PowerProfile.Balanced
    } else if (PowerProfiles.profile === PowerProfile.Balanced) {
      PowerProfiles.profile = PowerProfiles.hasPerformanceProfile ? PowerProfile.Performance : PowerProfile.PowerSaver
    } else {
      PowerProfiles.profile = PowerProfile.PowerSaver
    }
  }

  Text {
    id: label
    anchors.centerIn: parent
    text: root.text
    font.family: "JetBrainsMono Nerd Font Propo"
    font.pixelSize: 14
    color: charging ? Colors.success
         : capacity <= 15 ? Colors.error
         : capacity <= 30 ? Colors.warning
         : Colors.text_alt
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.cycleProfile()
    onEntered: root.tooltip.show(root, root.tooltipText)
    onExited: root.tooltip.hide()
  }
}
