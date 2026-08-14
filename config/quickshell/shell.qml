import QtQuick
import Quickshell
import "components"
import "modules"

Scope {
  id: root

  Variants {
    model: Quickshell.screens

    PanelWindow {
      required property var modelData
      screen: modelData

      anchors {
        top: true
        left: true
        right: true
      }

      color: Colors.surface
      implicitHeight: 42
      exclusionMode: ExclusionMode.Auto

      Tooltip {
        id: tooltip
      }

      Row {
        id: leftGroup
        anchors {
          left: parent.left
          leftMargin: 10
          verticalCenter: parent.verticalCenter
        }
        spacing: 8

        Workspaces {}
      }

      Row {
        id: centerGroup
        anchors {
          horizontalCenter: parent.horizontalCenter
          verticalCenter: parent.verticalCenter
        }
        spacing: 8

        Kmdot {}
        Clock {}
        Dnd {
          tooltip: tooltip
        }
      }

      Row {
        id: rightGroup
        anchors {
          right: parent.right
          rightMargin: 10
          verticalCenter: parent.verticalCenter
        }
        spacing: 8

        Network {
          tooltip: tooltip
        }
        Bluetooth {
          tooltip: tooltip
        }
        Audio {
          tooltip: tooltip
        }
        Backlight {}
        Battery {
          tooltip: tooltip
        }
      }
    }
  }
}
