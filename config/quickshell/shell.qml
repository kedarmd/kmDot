import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Wayland
import Quickshell.Services.Pam
import "components"
import "menu"
import "modules"

Scope {
  id: shellRoot

  property var activeLauncher: null
  property var openingSurface: null
  property bool hasNotifications: false
  property bool lockRequested: false
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
  property WallpaperLauncher wallpaperLauncher: WallpaperLauncher { scope: shellRoot }
  property BatteryPopup batteryPopup: BatteryPopup { scope: shellRoot }
  property VolumePopup volumePopup: VolumePopup { scope: shellRoot }
  property CalendarPopup calendarPopup: CalendarPopup { scope: shellRoot }
  property ServerModeDropdown serverModeDropdown: ServerModeDropdown { scope: shellRoot }
  property OpenCodeUsagePopup openCodeUsagePopup: OpenCodeUsagePopup { scope: shellRoot }
  property HandyPopup handyPopup: HandyPopup { scope: shellRoot }
  property DisplayPopup displayPopup: DisplayPopup { scope: shellRoot }
  property NotificationCenter notificationCenter: NotificationCenter { scope: shellRoot }
  property NotificationPopup notificationPopup: NotificationPopup { scope: shellRoot }
  property NotificationReplyPopup notificationReplyPopup: NotificationReplyPopup { scope: shellRoot }
  property OSDBase volumeOsd: OSDBase { sockName: "kmdot-osd-volume"; kind: "volume" }
  property OSDBase brightnessOsd: OSDBase { sockName: "kmdot-osd-brightness"; kind: "brightness" }
  property OSDBase microphoneOsd: OSDBase { sockName: "kmdot-osd-mic"; kind: "microphone" }

  // Keep all radio views in one registry. The stores deliberately do not know
  // about overlays; this is the shell-owned close-all boundary for the two
  // launchers, two dropdowns, and two add flows.
  readonly property var radioSurfaces: [
    shellRoot.wifiLauncher, shellRoot.bluetoothLauncher,
    shellRoot.wifiDropdown, shellRoot.bluetoothDropdown,
    shellRoot.wifiAddPopup, shellRoot.bluetoothAddPopup
  ]

  // Overlay coordinator: every PopupBase routes open() through here. The toast
  // (notificationPopup) is excluded — it stacks above cards and never closes them.
  function closeAllExcept(except) {
    const previousOpening = shellRoot.openingSurface
    shellRoot.openingSurface = except
    const launchers = [shellRoot.appLauncher, shellRoot.kmdotLauncher, shellRoot.systemLauncher,
      shellRoot.themeLauncher, shellRoot.connectionsLauncher, shellRoot.keybindsLauncher,
      shellRoot.clipboardLauncher, shellRoot.handyLauncher, shellRoot.wallpaperLauncher]
    for (const l of launchers) {
      if (l && l !== except) l.closeLauncher()
    }
    const popups = [shellRoot.confirmPopup, shellRoot.batteryPopup,
      shellRoot.volumePopup, shellRoot.calendarPopup, shellRoot.serverModeDropdown,
      shellRoot.openCodeUsagePopup, shellRoot.handyPopup, shellRoot.displayPopup,
      shellRoot.notificationCenter, shellRoot.notificationReplyPopup]
    for (const p of popups) {
      if (p && p !== except) p.close()
    }

    // Keep this explicit after the kind-specific loops: it documents and
    // enforces that every radio view participates in cross-kind coordination,
    // including the two add flows which have no socket of their own.
    for (const surface of shellRoot.radioSurfaces) {
      if (!surface || surface === except) continue
      if (surface.closeLauncher) surface.closeLauncher()
      else if (surface.close) surface.close()
    }
    shellRoot.openingSurface = previousOpening
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

  // Native Wayland session lock. Keep it in the long-lived shell process so
  // the lock owner is never a short-lived overlay or launcher process.
  WlSessionLock {
    id: sessionLock

    LockScreenSurface {
      lock: sessionLock
      shell: shellRoot
    }
  }

  PamContext {
    id: lockPam
    config: "hyprlock"
    onResponseRequiredChanged: {
      if (lockPam.responseRequired) lockPam.respond(lockState.password)
    }
    onCompleted: result => {
      lockState.password = ""
      if (result === PamResult.Success) {
        lockState.unlocking = true
        unlockTransitionTimer.restart()
      } else {
        lockState.unlocking = false
        shellRoot.lockRequested = false
        lockError = true
      }
    }
  }

  IpcHandler {
    target: "lockscreen"
    function lock(): void {
      if (sessionLock.locked || shellRoot.lockRequested) return
      shellRoot.lockRequested = true
      lockError = false
      lockState.password = ""
      lockState.unlocking = false
      sessionLock.locked = true
    }
    function isLocked(): bool { return sessionLock.locked }
  }

  // Shared credential state is surfaced into each per-screen surface through
  // this shell-owned object, while password input itself stays in the surface.
  QtObject {
    id: lockState
    property string password: ""
    property bool error: false
    property bool authenticating: lockPam.active
    property bool unlocking: false
  }
  property alias lockPassword: lockState.password
  property alias lockError: lockState.error
  readonly property bool lockAuthenticating: lockPam.active
  readonly property bool lockUnlocking: lockState.unlocking

  Timer {
    id: unlockTransitionTimer
    interval: Tokens.motionStandard
    onTriggered: {
      sessionLock.locked = false
      shellRoot.lockRequested = false
      lockState.unlocking = false
    }
  }

  function submitLockPassword() {
    if (!sessionLock.secure || lockPam.active || !lockState.password.length) return
    lockState.error = false
    lockPam.user = Quickshell.env("USER")
    if (!lockPam.start()) lockState.error = true
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
      if (shellRoot.notificationCenter.opened) {
        shellRoot.hasNotifications = false
        shellRoot.notificationPopup.dismissAll()
      }
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
        id: barWindow
        required property var modelData
        screen: modelData

        anchors {
          top: true
          left: true
          right: true
        }

        color: Colors.surface
        implicitHeight: 48
        exclusionMode: ExclusionMode.Auto

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
          leftMargin: 12
          verticalCenter: parent.verticalCenter
        }
        spacing: 12

        Kmdot {}
        Workspaces {}
      }

      Item {
        id: centerGroup
        width: calendarModule.width
        height: 32
        anchors {
          horizontalCenter: parent.horizontalCenter
          verticalCenter: parent.verticalCenter
        }
        Clock {
          id: calendarModule
          anchors.centerIn: parent
          popupRef: calendarPopup
        }
      }

      Row {
        id: rightGroup
        anchors {
          right: parent.right
          rightMargin: 12
          verticalCenter: parent.verticalCenter
        }
        spacing: 8

        HiddenModules {
          id: hiddenTray
          stayOpen: serverModeDropdown.opened || openCodeUsagePopup.opened || handyPopup.opened
          AttentionMode {}
          ServerMode {
            popupRef: serverModeDropdown
          }
          OpenCodeUsage {
            popupRef: openCodeUsagePopup
          }
          Handy {
            popupRef: handyPopup
          }
        }
        Display {
          popupRef: displayPopup
        }
        Audio {
          popupRef: volumePopup
        }
        Network {
          popupRef: wifiDropdown
        }
        Bluetooth {
          popupRef: bluetoothDropdown
        }
        Battery {
          popupRef: batteryPopup
        }
        Dnd {
          id: dndModule
          hasNotifications: shellRoot.hasNotifications
        }
      }
    }
  }
}
