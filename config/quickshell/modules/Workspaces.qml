import QtQuick
import Quickshell.Hyprland
import qs

Item {
  id: root
  implicitHeight: 30
  width: row.width

  function workspace(id) {
    for (const ws of Hyprland.workspaces.values) {
      if (ws.id === id) return ws
    }
    return null
  }

  Row {
    id: row
    spacing: 0

    Repeater {
      model: 5

      delegate: Component {
        Rectangle {
          required property int index

          readonly property int wsId: index + 1
          readonly property bool active: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === wsId
          readonly property bool urgent: {
            var ws = root.workspace(wsId)
            return ws ? ws.urgent : false
          }

          width: label.implicitWidth + 26
          height: 30
          radius: 8
          color: active ? Colors.border : "transparent"
          Behavior on color {
            ColorAnimation {
              duration: 200
            }
          }

          Text {
            id: label
            anchors.centerIn: parent
            text: wsId.toString()
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 14
            font.weight: parent.active ? Font.Bold : Font.Normal
            color: parent.urgent ? Colors.error
                 : parent.active ? Colors.text
                 : mouseArea.containsMouse ? Colors.text
                 : Colors.text_alt
          }

          MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Hyprland.dispatch("workspace", String(wsId))
          }
        }
      }
    }
  }
}
