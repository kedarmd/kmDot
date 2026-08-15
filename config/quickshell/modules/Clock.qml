import QtQuick
import Quickshell
import Quickshell.Io
import qs

Item {
  id: root
  implicitHeight: 30
  width: label.implicitWidth + 20

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  Text {
    id: label
    anchors.centerIn: parent
    text: root.formatClock(clock.date)
    font.family: "JetBrainsMono Nerd Font Propo"
    font.pixelSize: 14
    color: Colors.text_alt
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: toggleProc.exec(["sh", "-c", "$HOME/.config/kmdot/quickshell/scripts/toggle.sh kmdot-calendar"])
  }

  Process {
    id: toggleProc
  }

  function formatClock(date) {
    var days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    var day = date.getDate()
    var suffix = "th"
    if (day % 10 === 1 && day !== 11) suffix = "st"
    else if (day % 10 === 2 && day !== 12) suffix = "nd"
    else if (day % 10 === 3 && day !== 13) suffix = "rd"

    var hours = date.getHours()
    var ampm = hours >= 12 ? "PM" : "AM"
    var h12 = hours % 12
    if (h12 === 0) h12 = 12
    var hh = h12 < 10 ? "0" + h12 : "" + h12
    var mm = date.getMinutes() < 10 ? "0" + date.getMinutes() : "" + date.getMinutes()

    return days[date.getDay()] + " " + day + suffix + " " + months[date.getMonth()] + " - " + hh + ":" + mm + " " + ampm
  }
}
