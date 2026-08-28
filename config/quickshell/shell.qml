import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
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
  property WifiDropdown wifiDropdown: WifiDropdown { scope: shellRoot }
  property BluetoothDropdown bluetoothDropdown: BluetoothDropdown { scope: shellRoot }
  property WifiAddPopup wifiAddPopup: WifiAddPopup { scope: shellRoot }
  property BluetoothAddPopup bluetoothAddPopup: BluetoothAddPopup { scope: shellRoot }
  property ConfirmPopup confirmPopup: ConfirmPopup { scope: shellRoot }
  property KeybindsLauncher keybindsLauncher: KeybindsLauncher { scope: shellRoot }
  property ClipboardLauncher clipboardLauncher: ClipboardLauncher { scope: shellRoot }
  property HandyLauncher handyLauncher: HandyLauncher { scope: shellRoot }
  property BatteryPopup batteryPopup: BatteryPopup { scope: shellRoot }
  property VolumePopup volumePopup: VolumePopup { scope: shellRoot }
  property CalendarPopup calendarPopup: CalendarPopup { scope: shellRoot }
  property ServerModeDropdown serverModeDropdown: ServerModeDropdown { scope: shellRoot }
  property OpenCodeUsagePopup openCodeUsagePopup: OpenCodeUsagePopup { scope: shellRoot }
  property HandyPopup handyPopup: HandyPopup { scope: shellRoot }
  property DisplayPopup displayPopup: DisplayPopup { scope: shellRoot }
  property NotificationCenter notificationCenter: NotificationCenter { scope: shellRoot }
  property NotificationPopup notificationPopup: NotificationPopup { scope: shellRoot }

  NotificationServer {
    id: notifServer
    keepOnReload: true
    actionsSupported: true
    bodySupported: true
    imageSupported: true
    inlineReplySupported: true
    bodyMarkupSupported: false
    bodyHyperlinksSupported: false
    bodyImagesSupported: false
    actionIconsSupported: false

    onNotification: notification => {
      notification.tracked = true
      shellRoot.notificationPopup.addNotification(notification)
      if (shellRoot.notificationCenter)
        shellRoot.notificationCenter.addToHistory(notification)
    }
  }

  Component.onCompleted: {
    // Force-instantiate the calendar popup at startup so its 30-min resync
    // timer (and the initial ICS fetch) run even if it's never opened.
    calendarPopup
  }

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

        Binding {
          target: dndModule
          property: "count"
          value: notifServer.trackedNotifications.count
        }

      Tooltip {
        id: tooltip
      }

      IpcHandler {
        target: "notifications"

        function togglePanel(): void {
          shellRoot.notificationCenter.toggle()
        }

        function toggleDnd(): void {
          DnDState.dndEnabled = !DnDState.dndEnabled
        }

        function clearAll(): void {
          shellRoot.notificationCenter.clearAll()
        }

        function dismiss(id: string): void {
          const n = notifServer.trackedNotifications.values
          for (let i = 0; i < n.length; i++) {
            if (String(n[i].id) === id) { n[i].dismiss(); break }
          }
        }

        function isDnd(): bool {
          return DnDState.dndEnabled
        }
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

        AttentionMode {
          tooltip: tooltip
        }
        Kmdot {}
        Clock {
          popup: calendarPopup
        }
        Dnd {
          id: dndModule
          tooltip: tooltip
          count: 0
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

        HiddenModules {
          id: hiddenTray
          stayOpen: serverModeDropdown.opened || openCodeUsagePopup.opened || handyPopup.opened
          OpenCodeUsage {
            tooltip: tooltip
            popup: openCodeUsagePopup
          }
          Handy {
            tooltip: tooltip
            popup: handyPopup
          }
          ServerMode {
            dropdown: serverModeDropdown
          }
        }
        Network {
          tooltip: tooltip
          dropdown: wifiDropdown
        }
        Bluetooth {
          tooltip: tooltip
          dropdown: bluetoothDropdown
        }
        Audio {
          tooltip: tooltip
          popup: volumePopup
        }
        Battery {
          tooltip: tooltip
          popup: batteryPopup
        }
        Display {
          tooltip: tooltip
          popup: displayPopup
        }
      }
    }
  }
}
