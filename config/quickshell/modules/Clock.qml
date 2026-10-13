import QtQuick
import Quickshell
import qs
import "../components"

BarModule {
  id: root
  sock: "kmdot-calendar"
  textSize: 14

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  text: root.formatClock(clock.date)

  function formatClock(date) {
    var days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    var day = date.getDate()
    var hours = date.getHours()
    var ampm = hours >= 12 ? "PM" : "AM"
    var h12 = hours % 12
    if (h12 === 0) h12 = 12
    var hh = h12 < 10 ? "0" + h12 : "" + h12
    var mm = date.getMinutes() < 10 ? "0" + date.getMinutes() : "" + date.getMinutes()

    return days[date.getDay()] + ", " + months[date.getMonth()] + " " + day + "  " + hh + ":" + mm + " " + ampm
  }
}
