import QtQuick
import Quickshell
import "components"
import "menu"
import "modules"

Scope {
  id: shellRoot

  property var activeLauncher: null
  property AppLauncher appLauncher: AppLauncher { scope: shellRoot }
  property KmdotLauncher kmdotLauncher: KmdotLauncher { scope: shellRoot }
  property SystemLauncher systemLauncher: SystemLauncher { scope: shellRoot }
  property ThemeLauncher themeLauncher: ThemeLauncher { scope: shellRoot }
  property ConnectionsLauncher connectionsLauncher: ConnectionsLauncher { scope: shellRoot }
  property WifiLauncher wifiLauncher: WifiLauncher { scope: shellRoot }
  property BluetoothLauncher bluetoothLauncher: BluetoothLauncher { scope: shellRoot }
  property KeybindsLauncher keybindsLauncher: KeybindsLauncher { scope: shellRoot }
  property BatteryPopup batteryPopup: BatteryPopup { scope: shellRoot }
  property VolumePopup volumePopup: VolumePopup { scope: shellRoot }
  property BrightnessPopup brightnessPopup: BrightnessPopup { scope: shellRoot }

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
