import QtQuick
import Quickshell.Hyprland
import qs
import "../components"

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

  function activateWorkspace(id) {
    const ws = workspace(id)
    if (ws) {
      ws.activate()
    } else if (Hyprland.usingLua) {
      Hyprland.dispatch('hl.dsp.focus({ workspace = "' + id + '" })')
    } else {
      Hyprland.dispatch("workspace " + id)
    }
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
          radius: height / 2
          color: active ? Tokens.primaryContainer
               : urgent ? Tokens.errorContainer
               : "transparent"
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
            font.pixelSize: 15
            font.weight: parent.active ? Font.Bold : Font.Normal
            color: parent.urgent ? Tokens.on_error_container
                 : parent.active ? Tokens.on_primary_container
                 : mouseArea.containsMouse ? Colors.text
                 : Colors.text_alt
          }

          StateLayer {
            anchors.fill: parent
            radius: parent.radius
            hovered: mouseArea.containsMouse
            pressed: mouseArea.pressed
          }

          MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.activateWorkspace(wsId)
          }
        }
      }
    }
  }
}
