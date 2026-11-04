import QtQuick
import Quickshell.Hyprland
import Quickshell.Io
import qs

Item {
  id: root
  implicitHeight: 32
  width: 16 + root.workspaceIds.length * 28

  property var workspaceState: []
  property int focusedId: 0

  readonly property var workspaceIds: {
    const ids = [1, 2, 3, 4, 5]
    if (focusedId > 0 && !ids.includes(focusedId)) ids.push(focusedId)
    return ids
  }

  // Read compositor counts, rather than the separately tracked Wayland
  // toplevel membership which can retain stale workspace associations.
  Process {
    id: snapshot
    command: ["bash", "-c", "set -o pipefail; hyprctl -j --batch 'workspaces;activeworkspace' | jq -sc 'select(length == 2 and (.[0] | type) == \"array\" and (.[1].id | type) == \"number\")'"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const state = JSON.parse(text)
          root.workspaceState = state[0]
          root.focusedId = state[1].id
        } catch (_) { /* Keep the last complete snapshot during reconnects. */ }
      }
    }
  }

  // Events give immediate updates; polling also heals missed/reconnect events.
  Timer { id: refresh; interval: 50; onTriggered: { if (!snapshot.running) snapshot.running = true } }
  Timer { interval: 1000; running: true; repeat: true; onTriggered: { if (!snapshot.running) snapshot.running = true } }
  Connections {
    target: Hyprland
    function onRawEvent(event) { refresh.restart() }
  }

  Rectangle {
    anchors.fill: parent
    radius: 16
    color: Colors.surface_alt
  }

  function workspace(id) {
    for (const ws of workspaceState) {
      if (ws.id === id) return ws
    }
    return null
  }

  function activateWorkspace(id) {
    if (Hyprland.usingLua) {
      Hyprland.dispatch('hl.dsp.focus({ workspace = "' + id + '" })')
    } else {
      Hyprland.dispatch("workspace " + id)
    }
  }

  Row {
    anchors.centerIn: parent

    Repeater {
      model: root.workspaceIds

      delegate: Item {
        id: slot
        required property int index

        readonly property int wsId: root.workspaceIds[index]
        readonly property bool active: {
          return root.focusedId === wsId
        }
        readonly property bool urgent: {
          for (const ws of Hyprland.workspaces.values) {
            if (ws.id === wsId) return ws.urgent
          }
          return false
        }
        readonly property bool occupied: {
          const ws = root.workspace(wsId)
          return ws ? ws.windows > 0 : false
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
          border.width: !slot.active && !slot.occupied && !slot.urgent ? 1.5 : 0
          border.color: Colors.muted
          // Urgency wins even on the active workspace; shape still shows focus.
          color: slot.urgent ? Colors.urgent
               : slot.active ? Colors.workspace_active
               : mouseArea.containsMouse ? Colors.text_alt
               : slot.occupied ? Colors.muted
               : "transparent"
          scale: mouseArea.pressed ? 0.9 : 1

          Behavior on width {
            NumberAnimation { duration: Tokens.motionEmphasized; easing.type: Tokens.motionEasing }
          }
          Behavior on color {
            ColorAnimation { duration: Tokens.motionEmphasized; easing.type: Tokens.motionEasing }
          }
          Behavior on scale {
            NumberAnimation { duration: Tokens.motionFast; easing.type: Tokens.motionEasing }
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
