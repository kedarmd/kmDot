import QtQuick
import Quickshell.Hyprland
import qs

Item {
  id: root
  implicitHeight: 32
  width: 156

  Rectangle {
    anchors.fill: parent
    radius: 16
    color: Colors.base
  }

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
    anchors.centerIn: parent

    Repeater {
      model: 5

      delegate: Item {
        id: slot
        required property int index

        readonly property int wsId: index + 1
        readonly property bool active: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === wsId
        readonly property bool urgent: {
          const ws = root.workspace(wsId)
          return ws ? ws.urgent : false
        }
        readonly property bool occupied: {
          const ws = root.workspace(wsId)
          return ws ? ws.toplevels.values.length > 0 : false
        }

        // Stable hit targets keep every workspace easy to click during morphs.
        width: 28
        height: 32
        Accessible.role: Accessible.Button
        Accessible.name: "Workspace " + wsId + (occupied ? ", occupied" : ", empty")
                         + (urgent ? ", needs attention" : "")
        Accessible.checkable: true
        Accessible.checked: active
        Accessible.onPressAction: root.activateWorkspace(wsId)

        Rectangle {
          anchors.centerIn: parent
          width: slot.active ? 24 : 10
          height: 10
          radius: height / 2
          // Urgency wins even on the active workspace; shape still shows focus.
          color: slot.urgent ? Colors.urgent
               : slot.active ? Colors.primary
               : mouseArea.containsMouse ? Colors.text_alt
               : slot.occupied ? Colors.muted
               : Colors.outline_variant
          scale: mouseArea.pressed ? 0.9 : 1

          Behavior on width {
            NumberAnimation { duration: Tokens.motionEmphasized; easing.type: Easing.InOutCubic }
          }
          Behavior on color {
            ColorAnimation { duration: Tokens.motionEmphasized; easing.type: Easing.InOutCubic }
          }
          Behavior on scale {
            NumberAnimation { duration: Tokens.motionFast; easing.type: Easing.OutCubic }
          }
        }

        MouseArea {
          id: mouseArea
          anchors.fill: parent
          hoverEnabled: true
          acceptedButtons: Qt.LeftButton
          cursorShape: Qt.PointingHandCursor
          onClicked: root.activateWorkspace(slot.wsId)
        }
      }
    }
  }
}
