import QtQuick
import qs

Rectangle {
  default property alias modules: row.data

  width: row.implicitWidth
  height: Tokens.barIslandHeight
  radius: height / 2
  color: Colors.surface_alt

  Row {
    id: row
    anchors.centerIn: parent
  }
}
