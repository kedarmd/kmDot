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
  property bool hasNotifications: false
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

  // Overlay coordinator: every PopupBase routes open() through here. The toast
  // (notificationPopup) is excluded — it stacks above cards and never closes them.
  function closeAllExcept(except) {
    const launchers = [shellRoot.appLauncher, shellRoot.kmdotLauncher, shellRoot.systemLauncher,
      shellRoot.themeLauncher, shellRoot.connectionsLauncher, shellRoot.wifiLauncher,
      shellRoot.bluetoothLauncher, shellRoot.keybindsLauncher, shellRoot.clipboardLauncher,
      shellRoot.handyLauncher]
    for (const l of launchers) {
      if (l && l !== except) l.closeLauncher()
    }
    const popups = [shellRoot.wifiDropdown, shellRoot.bluetoothDropdown, shellRoot.wifiAddPopup,
      shellRoot.bluetoothAddPopup, shellRoot.confirmPopup, shellRoot.batteryPopup,
      shellRoot.volumePopup, shellRoot.calendarPopup, shellRoot.serverModeDropdown,
      shellRoot.openCodeUsagePopup, shellRoot.handyPopup, shellRoot.displayPopup,
      shellRoot.notificationCenter]
    for (const p of popups) {
      if (p && p !== except) p.close()
    }
  }

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
      shellRoot.hasNotifications = true
      shellRoot.notificationPopup.addNotification(notification)
      if (shellRoot.notificationCenter)
        shellRoot.notificationCenter.addToHistory(notification)
    }
  }

  Timer {
    interval: 3000
    repeat: true
    running: true
    onTriggered: {
      if (shellRoot.hasNotifications && notifServer.trackedNotifications.count === 0)
        shellRoot.hasNotifications = false
    }
  }

  Connections {
    target: shellRoot.notificationCenter
    function onOpenedChanged() {
      if (shellRoot.notificationCenter.opened)
        shellRoot.hasNotifications = false
    }
  }

  // Handy playback lifecycle (issue #55, spec #51): audio survives switching
  // between the launcher and the popup, and stops once BOTH are closed.
  // The stop is deferred 150ms (same grace as the hidden-tray timer): a
  // view switch closes one surface just before opening the other via
  // closeAllExcept, so a synchronous both-closed check would misfire
  // mid-switch and kill audio that should survive. Opening either surface
  // cancels the pending stop.
  Timer {
    id: handyStopTimer
    interval: 150
    onTriggered: {
      if (!shellRoot.handyPopup.opened && !shellRoot.handyLauncher.opened)
        HandyStore.stopPlayback()
    }
  }
  function stopHandyIfBothClosed() {
    if (!shellRoot.handyPopup.opened && !shellRoot.handyLauncher.opened)
      handyStopTimer.restart()
    else handyStopTimer.stop()
  }
  Connections {
    target: shellRoot.handyPopup
    function onOpenedChanged() { shellRoot.stopHandyIfBothClosed() }
  }
  Connections {
    target: shellRoot.handyLauncher
    function onOpenedChanged() { shellRoot.stopHandyIfBothClosed() }
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
          popupRef: calendarPopup
        }
        Dnd {
          id: dndModule
          tooltip: tooltip
          hasNotifications: shellRoot.hasNotifications
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
            popupRef: openCodeUsagePopup
          }
          Handy {
            tooltip: tooltip
            popupRef: handyPopup
          }
          ServerMode {
            popupRef: serverModeDropdown
          }
        }
        Network {
          tooltip: tooltip
          popupRef: wifiDropdown
        }
        Bluetooth {
          tooltip: tooltip
          popupRef: bluetoothDropdown
        }
        Audio {
          tooltip: tooltip
          popupRef: volumePopup
        }
        Battery {
          tooltip: tooltip
          popupRef: batteryPopup
        }
        Display {
          tooltip: tooltip
          popupRef: displayPopup
        }
      }
    }
  }
}
