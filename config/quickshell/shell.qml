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
  property var pendingNotificationRefreshes: ({})
  property bool lockRequested: false
  property bool lockRevealVisible: false
  property bool lockRevealCovered: false
  readonly property int lockTransitionDuration: Tokens.reducedMotion ? 0 : 320
  property bool loginRevealVisible: false
  property bool loginRevealCovered: true
  readonly property string loginRevealMarker: Quickshell.env("XDG_RUNTIME_DIR") + "/kmdot-login-reveal"
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
  property HexLauncher hexLauncher: HexLauncher { scope: shellRoot }
  property WallpaperLauncher wallpaperLauncher: WallpaperLauncher { scope: shellRoot }
  property BatteryPopup batteryPopup: BatteryPopup { scope: shellRoot }
  property VolumePopup volumePopup: VolumePopup { scope: shellRoot }
  property CalendarPopup calendarPopup: CalendarPopup { scope: shellRoot }
  property ServerModeDropdown serverModeDropdown: ServerModeDropdown { scope: shellRoot }
  property OpenCodeUsagePopup openCodeUsagePopup: OpenCodeUsagePopup { scope: shellRoot }
  property HandyPopup handyPopup: HandyPopup { scope: shellRoot }
  property HexPopup hexPopup: HexPopup { scope: shellRoot }
  property SystemMonitorPopup systemMonitorPopup: SystemMonitorPopup { scope: shellRoot }
  property HexHud hexHud: HexHud {}
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

  // Resolve native notification objects by ID at the point of use. UI models
  // keep scalar IDs only; storing QObject wrappers in ListModel roles can leave
  // delegates holding stale references after replacement or dismissal.
  function notificationById(id) {
    const tracked = notifServer.trackedNotifications.values || []
    for (let i = 0; i < tracked.length; i++) {
      if (tracked[i].id === id) return tracked[i]
    }
    return null
  }

  // Quickshell 0.3.1 updates a replaced notification object in place without
  // emitting NotificationServer.notification again. Coalesce its property
  // change signals so the scalar UI models receive one fresh snapshot.
  function scheduleNotificationRefresh(id) {
    const key = String(id)
    if (shellRoot.pendingNotificationRefreshes[key]) return

    const pending = Object.assign({}, shellRoot.pendingNotificationRefreshes)
    pending[key] = true
    shellRoot.pendingNotificationRefreshes = pending

    Qt.callLater(() => {
      const next = Object.assign({}, shellRoot.pendingNotificationRefreshes)
      delete next[key]
      shellRoot.pendingNotificationRefreshes = next

      const notification = shellRoot.notificationById(id)
      if (!notification) return
      shellRoot.notificationPopup.updateNotification(notification)
      shellRoot.notificationCenter.addToHistory(notification)
    })
  }

  // Overlay coordinator: every PopupBase routes open() through here. The toast
  // (notificationPopup) is excluded — it stacks above cards and never closes them.
  function closeAllExcept(except) {
    const previousOpening = shellRoot.openingSurface
    shellRoot.openingSurface = except
    const launchers = [shellRoot.kmdotLauncher, shellRoot.systemLauncher,
      shellRoot.themeLauncher, shellRoot.connectionsLauncher, shellRoot.keybindsLauncher,
      shellRoot.clipboardLauncher, shellRoot.handyLauncher, shellRoot.hexLauncher, shellRoot.wallpaperLauncher]
    for (const l of launchers) {
      if (l && l !== except) l.closeLauncher()
    }
    const popups = [shellRoot.confirmPopup, shellRoot.batteryPopup,
      shellRoot.volumePopup, shellRoot.calendarPopup, shellRoot.serverModeDropdown,
      shellRoot.openCodeUsagePopup, shellRoot.handyPopup, shellRoot.hexPopup, shellRoot.displayPopup,
      shellRoot.systemMonitorPopup, shellRoot.notificationCenter, shellRoot.notificationReplyPopup]
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

  // Replacements mutate the tracked Notification QObject in place. Keep the
  // toast/history models as scalar snapshots and refresh them when those
  // native properties change; the Connections target follows model lifetime.
  Instantiator {
    model: notifServer.trackedNotifications

    delegate: Connections {
      required property var modelData
      target: modelData
      function onAppNameChanged() { shellRoot.scheduleNotificationRefresh(modelData.id) }
      function onAppIconChanged() { shellRoot.scheduleNotificationRefresh(modelData.id) }
      function onDesktopEntryChanged() { shellRoot.scheduleNotificationRefresh(modelData.id) }
      function onSummaryChanged() { shellRoot.scheduleNotificationRefresh(modelData.id) }
      function onBodyChanged() { shellRoot.scheduleNotificationRefresh(modelData.id) }
      function onUrgencyChanged() { shellRoot.scheduleNotificationRefresh(modelData.id) }
      function onActionsChanged() { shellRoot.scheduleNotificationRefresh(modelData.id) }
      function onHasInlineReplyChanged() { shellRoot.scheduleNotificationRefresh(modelData.id) }
      function onHintsChanged() { shellRoot.scheduleNotificationRefresh(modelData.id) }
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
        shellRoot.lockRevealVisible = true
        shellRoot.lockRevealCovered = true
        unlockTransitionTimer.restart()
      } else {
        lockState.unlocking = false
        shellRoot.lockRevealCovered = false
        shellRoot.lockRevealVisible = false
        shellRoot.lockRequested = false
        lockError = true
      }
    }
  }

  IpcHandler {
    target: "lockscreen"
    function lock(): void {
      if (sessionLock.locked || shellRoot.lockRequested) return
      unlockTransitionTimer.stop()
      unlockRevealCleanupTimer.stop()
      shellRoot.lockRevealVisible = false
      shellRoot.lockRevealCovered = false
      shellRoot.lockRequested = true
      lockError = false
      lockState.password = ""
      lockState.unlocking = false
      sessionLock.locked = true
    }
    function isLocked(): bool { return sessionLock.locked }
  }

  IpcHandler {
    target: "displayBrightness"
    function increase(): void { DisplayState.nudgeBar(1) }
    function decrease(): void { DisplayState.nudgeBar(-1) }
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
    // Let the one shell-wide cover finish covering the lockscreen before
    // releasing the native lock surface.
    interval: shellRoot.lockTransitionDuration + 50
    onTriggered: {
      sessionLock.locked = false
      shellRoot.lockRequested = false
      lockState.unlocking = false
      unlockRevealHoldTimer.restart()
    }
  }

  Timer {
    id: unlockRevealHoldTimer
    // Keep the cover fully opaque while Wayland tears down the lock surface.
    interval: 60
    onTriggered: {
      shellRoot.lockRevealCovered = false
      unlockRevealCleanupTimer.restart()
    }
  }

  Timer {
    id: unlockRevealCleanupTimer
    // Let the opacity animation finish before the overlay is unmapped.
    interval: shellRoot.lockTransitionDuration + 50
    onTriggered: shellRoot.lockRevealVisible = false
  }

  FileView {
    id: loginRevealMarkerFile
    path: shellRoot.loginRevealMarker
    printErrors: false
    onLoadFailed: function(error) {
      if (error !== FileViewError.FileNotFound) return
      // XDG_RUNTIME_DIR is cleared when this login session ends, so manual
      // Quickshell restarts won't replay the transition.
      loginRevealMarkerProc.running = true
      shellRoot.loginRevealVisible = true
      loginRevealStartTimer.restart()
    }
  }

  Process {
    id: loginRevealMarkerProc
    command: ["touch", shellRoot.loginRevealMarker]
  }

  Timer {
    id: loginRevealStartTimer
    interval: shellRoot.lockTransitionDuration > 0 ? 60 : 0
    onTriggered: {
      shellRoot.loginRevealCovered = false
      loginRevealCleanupTimer.restart()
    }
  }

  Timer {
    id: loginRevealCleanupTimer
    interval: shellRoot.lockTransitionDuration + 50
    onTriggered: shellRoot.loginRevealVisible = false
  }

  // The greeter cannot keep its surface alive after successful authentication.
  // This one-shot session overlay begins fully covered, then reveals the desktop
  // using the same base color and timing as the SDDM greeter's exit cover.
  Variants {
    model: Quickshell.screens
    PanelWindow {
      required property var modelData
      screen: modelData
      visible: shellRoot.loginRevealVisible
      color: "transparent"
      focusable: false
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.exclusionMode: ExclusionMode.Ignore
      anchors { top: true; bottom: true; left: true; right: true }

      Rectangle {
        anchors.fill: parent
        color: Colors.base
        opacity: shellRoot.loginRevealCovered ? 1 : 0
        Behavior on opacity {
          enabled: !shellRoot.loginRevealCovered
          NumberAnimation {
            duration: shellRoot.lockTransitionDuration
            easing.type: Easing.InOutCubic
          }
        }
      }
    }
  }

  // The native session-lock surface is destroyed at unlock, so it cannot
  // animate the desktop reveal itself. One full-screen cover fades over the
  // unchanged lockscreen, holds across lock teardown, then fades off the
  // desktop. This keeps the whole handoff on a single opacity animation.
  Variants {
    model: Quickshell.screens
    PanelWindow {
      required property var modelData
      screen: modelData
      visible: shellRoot.lockRevealVisible
      color: "transparent"
      focusable: false
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.exclusionMode: ExclusionMode.Ignore
      anchors { top: true; bottom: true; left: true; right: true }

      Rectangle {
        anchors.fill: parent
        color: Colors.base
        opacity: shellRoot.lockRevealCovered ? 1 : 0
        Behavior on opacity {
          NumberAnimation {
            duration: shellRoot.lockTransitionDuration
            easing.type: Easing.InOutCubic
          }
        }
      }
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
      if (shellRoot.hasNotifications
          && (notifServer.trackedNotifications.values || []).length === 0)
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
    // The migrated launcher's Wayland surfaces require a full process restart
    // for source changes. Theme/config data still refresh through FileView.
    Quickshell.watchFiles = false
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
        implicitHeight: 44
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

        SystemStats { popupRef: systemMonitorPopup }
        HiddenModules {
          id: hiddenTray
          stayOpen: serverModeDropdown.opened || openCodeUsagePopup.opened || handyPopup.opened || hexPopup.opened
          AttentionMode {}
          ServerMode {
            popupRef: serverModeDropdown
          }
          OpenCodeUsage {
            popupRef: openCodeUsagePopup
          }
          Handy {
            visible: DictationConfig.provider === "handy"
            popupRef: handyPopup
          }
          Hex {
            visible: DictationConfig.provider === "hex"
            popupRef: hexPopup
          }
        }
        Row {
          spacing: 0
          Display { popupRef: displayPopup }
          Audio { popupRef: volumePopup }
        }
        Row {
          spacing: 0
          Network { popupRef: wifiDropdown }
          Bluetooth { popupRef: bluetoothDropdown }
        }
        Row {
          spacing: 0
          Battery { popupRef: batteryPopup }
          Dnd {
            id: dndModule
            hasNotifications: shellRoot.hasNotifications
          }
        }
      }
    }
  }
}
