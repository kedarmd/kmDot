# Quickshell Functional Requirements Inventory

Phase 1 audit of the repository at base commit `9bba571c` on `main`, before the cleanup branch was created. This document records behavior and integration contracts only; it intentionally excludes legacy visual decisions. “Implemented and functional” means the repository contains an active implementation and wiring. Runtime behavior has not been exercised on a live desktop during this audit.

## Coverage and audit method

The audit covered every file under `config/quickshell/`, Quickshell-specific Hyprland keybindings/autostart/rules/idle actions, `sync/quickshell.sh`, theme-switcher integration and palette schema, Quickshell package/install/uninstall references, Polkit, SDDM integration, and related scripts in `config/hyprland/scripts/`. Screenshots were not used as evidence. Source references below identify the implementation and its principal callers; companion service scripts and state stores are included where they establish behavior.

## Feature inventory

### QS-01 — Per-monitor desktop bar and workspaces

- **Purpose / surface:** Desktop service; top bar entry on every connected screen.
- **Status:** Implemented and functional.
- **Entry points:** Starts from Hyprland autostart (`quickshell &`). Workspace pills are interactive; module clicks and wheels provide their documented actions. The bar is repeated over `Quickshell.screens`.
- **Capabilities:** Displays kmDot menu entry, active workspaces, centered clock/calendar entry, and right-side modules for attention mode, server mode, OpenCode usage, Handy, display/brightness, audio, network, Bluetooth, battery, and notifications/DND. Some right-side entries are in a collapsible hidden tray. Bar module controls include hover/tooltips, activity states, busy feedback, and popup dispatch.
- **State/data:** Hyprland workspace state; clock; module-specific live state; notification availability; tray expansion.
- **Dependencies/integrations:** Quickshell, Hyprland, system services described below, `toggle.sh` socket protocol, `components/BarModule.qml` and module QML.
- **Errors/edge cases:** One bar instance per screen; popups choose the source screen/anchor where supported. Tray stays expanded while selected long-lived panels are open. Bar restart is part of theme switching.
- **Acceptance criteria:** Bar is present on every active screen; workspace and module state reflect their sources; module actions open the appropriate feature; screen-specific popup anchoring remains coherent.
- **Sources:** `config/quickshell/shell.qml`, `config/quickshell/modules/*.qml`, `config/quickshell/components/BarModule.qml`, `config/quickshell/components/ModulePill.qml`, `config/hyprland/autostart.lua`, `config/hyprland/keybinds.lua`.

### QS-02 — Application launcher

- **Purpose / surface:** Launcher.
- **Status:** Implemented and functional.
- **Entry points:** Super+Space; kmDot menu → Applications; launcher socket `kmdot-launcher`.
- **Capabilities:** Search installed desktop entries by name, generic name, executable, keywords, comment, and ID; launch selected entry. Shared launcher behavior includes keyboard navigation, activation, and closing.
- **State/data:** Asynchronously populated `DesktopEntries.applications`; search query and result selection.
- **Dependencies/integrations:** Quickshell DesktopEntries, `LauncherBase.qml`, `toggle.sh` / Unix socket.
- **Errors/edge cases:** Desktop entries may arrive after initial launch and trigger a rebuild; optional/non-string fields must be safely coerced. Socket helper attempts to recover a missing or stale Quickshell process.
- **Acceptance criteria:** Applications become searchable when the desktop-entry model populates; selecting a result launches it; missing/stale socket recovery does not leave launcher inaccessible.
- **Sources:** `config/quickshell/AppLauncher.qml`, `config/quickshell/components/LauncherBase.qml`, `config/quickshell/scripts/launcher.sh`, `config/quickshell/scripts/toggle.sh`, `config/hyprland/keybinds.lua`.

### QS-03 — kmDot command launcher and nested navigation

- **Purpose / surface:** Launcher.
- **Status:** Implemented and functional.
- **Entry points:** Super+K; `kmdot-kmdot` socket. Entries can open other launchers.
- **Capabilities:** Top-level access to Applications, Clipboard, Connections, Handy, Keybinds, System, and Themes. Search can reach Wi-Fi/Bluetooth children and system commands through nested entries; activation dispatches to the owning launcher or runs the selected system action.
- **State/data:** Static entries and child item pools supplied by the relevant launchers.
- **Dependencies/integrations:** Launcher coordinator in `shell.qml`, child launchers, `LauncherBase.qml`, socket helper.
- **Errors/edge cases:** Empty query presents top-level entries; dynamic theme pool is not included in nested search. Opening one coordinated surface closes competing launchers/popups.
- **Acceptance criteria:** Each top-level entry reaches its feature; nested search results identify and dispatch to their correct destination; only one coordinated overlay is left open.
- **Sources:** `config/quickshell/menu/KmdotLauncher.qml`, `config/quickshell/shell.qml`, `config/quickshell/components/LauncherBase.qml`.

### QS-04 — System actions

- **Purpose / surface:** Launcher and lock-screen actions.
- **Status:** Implemented and functional.
- **Entry points:** Super+Escape; kmDot menu → System; nested kmDot search; lock screen power controls.
- **Capabilities:** Lock, logout from Hyprland, restart, shutdown, and suspend. Lock delegates to the session-lock feature; power actions use system commands.
- **State/data:** Current compositor/session state.
- **Dependencies/integrations:** Hyprland dispatch, `systemctl`, lockscreen IPC.
- **Errors/edge cases:** System action execution can fail if the corresponding command/service is unavailable; lock is guarded against duplicate requests.
- **Acceptance criteria:** Each listed action dispatches the intended system operation, and Lock enters the supported lock flow.
- **Sources:** `config/quickshell/menu/SystemLauncher.qml`, `config/quickshell/menu/LockScreenSurface.qml`, `config/quickshell/shell.qml`, `config/hyprland/keybinds.lua`.

### QS-05 — Theme selection and theme-switcher integration

- **Purpose / surface:** Launcher plus desktop service integration.
- **Status:** Implemented and functional.
- **Entry points:** Super+T; kmDot menu → Themes; socket `kmdot-theme`; CLI `theme-switcher/main.sh <theme>`.
- **Capabilities:** Lists available themes, identifies the selected theme, applies a selection through the shared theme switcher, regenerates Quickshell color data, and restarts Quickshell so surfaces and sockets reload.
- **State/data:** `~/.cache/kmdot_theme`; palette source under `~/.config/kmdot/themes/<theme>/quickshell.conf`.
- **Dependencies/integrations:** `theme-switcher/main.sh`, `theme-switcher/hooks/quickshell.sh`, `render-quickshell.sh`, `quickshell.roles`, `list-themes.sh`; other theme hooks run as part of the shared switch.
- **Errors/edge cases:** Theme changes are rejected while the session is locked. Palette schema validation rejects missing, duplicate, unknown, or malformed roles. Launcher starts the switch detached because the hook terminates/restarts Quickshell. A theme change affects applications beyond Quickshell through the shared switcher.
- **Acceptance criteria:** All supported themes can be selected; Quickshell receives the selected theme data and restarts once; other theme hooks continue to run; lock state blocks switching.
- **Sources:** `config/quickshell/menu/ThemeLauncher.qml`, `config/quickshell/scripts/list-themes.sh`, `theme-switcher/main.sh`, `theme-switcher/hooks/quickshell.sh`, `theme-switcher/render-quickshell.sh`, `theme-switcher/quickshell.roles`, `themes/*/quickshell.conf`, `sync/quickshell.sh`.

### QS-06 — Wallpaper selection

- **Purpose / surface:** Launcher.
- **Status:** Implemented and functional.
- **Entry points:** Super+Ctrl+Space; socket `kmdot-wallpaper`.
- **Capabilities:** Lists the active theme’s wallpapers, marks the active item, supports keyboard selection and apply, and updates active wallpaper caches. Autostart applies the cached wallpaper or the first available image; theme changes select the first wallpaper for the new theme.
- **State/data:** Theme-specific files in `themes/<theme>/wallpapers/`; active theme and per-theme wallpaper cache under `~/.cache`.
- **Dependencies/integrations:** `list-wallpapers.sh`, Hyprland wallpaper scripts (`wallpaper-common.sh`, `set_wallpaper.sh`, `apply_wallpaper.sh`), `awww`, optional image dimension tool, SDDM wallpaper mirror.
- **Errors/edge cases:** Invalid paths are rejected; missing/stale cache resolves to the first item; ordering relies on zero-padded numeric file names. Wallpaper scripts are shared with Hyprland and SDDM.
- **Acceptance criteria:** Selection applies only a wallpaper belonging to the active theme, persists the active choice, and startup recovers from stale cache paths.
- **Sources:** `config/quickshell/menu/WallpaperLauncher.qml`, `config/quickshell/scripts/list-wallpapers.sh`, `config/hyprland/scripts/wallpaper-common.sh`, `config/hyprland/scripts/set_wallpaper.sh`, `config/hyprland/scripts/apply_wallpaper.sh`, `theme-switcher/hooks/wallpapers.sh`, `config/hyprland/keybinds.lua`.

### QS-07 — Clipboard history

- **Purpose / surface:** Launcher and desktop service.
- **Status:** Implemented and functional.
- **Entry points:** Super+V; kmDot menu → Clipboard; socket `kmdot-clipboard`. Daemon starts at login and during Quickshell sync when a Wayland session is available.
- **Capabilities:** Captures text and PNG clipboard offers; deduplicates by SHA-256; lists text and image history with optional thumbnails; selecting restores an item to the clipboard; Clear removes history without replacing the current clipboard.
- **State/data:** `~/.cache/kmdot/clipboard/{index,text,img,thumb}`; one-day retention.
- **Dependencies/integrations:** `wl-paste`, `wl-copy`, `flock`, `sha256sum`, optional ImageMagick, `clipboard-daemon.sh`, capture/list/copy/clear scripts. Hyprshot image offers are captured through the image watcher.
- **Errors/edge cases:** Two watchers may fire for one clipboard change; capture/index/GC are serialized and payload writes are atomic. Daemon avoids duplicate watcher sets. Wayland clipboard tools must be available.
- **Acceptance criteria:** Text and PNG offers appear once in history, restore correctly, expire after retention, and clearing history leaves the live clipboard unchanged.
- **Sources:** `config/quickshell/menu/ClipboardLauncher.qml`, `config/quickshell/scripts/clipboard-{daemon,capture,list,copy,clear}.sh`, `config/hyprland/autostart.lua`, `sync/quickshell.sh`, `config/hyprland/keybinds.lua`.

### QS-08 — Wi-Fi management surfaces

- **Purpose / surface:** Launcher and popup panels.
- **Status:** Implemented and functional; two overlapping interaction paths are present.
- **Entry points:** Bar Network click opens `WifiDropdown`; `kmdot-wifi` launcher is available through Connections, nested kmDot search, and the bar module configuration; kmDot Connections → Wi-Fi. Dropdown has actions that open add-network/confirmation flows.
- **Capabilities:** Shows radio state, current connection and scan results; scans, connects to saved/open/secured networks, disconnects, toggles radio, manages saved networks, forgets networks, and handles password prompting and errors. Dropdown/add flows support connection setup and confirmation.
- **State/data:** Radio enabled state, scan results, saved connections, active SSID, busy/error state, input password.
- **Dependencies/integrations:** `nmcli`, NetworkManager; `Wifi.qml` shared state, `components/wifi.js`, `WifiLauncher.qml`, `WifiDropdown.qml`, `WifiAddPopup.qml`, `ConfirmPopup.qml`, `PopupBase.qml`, socket toggle.
- **Errors/edge cases:** Escaped SSIDs (including colons); empty scans after radio enable are retried; network operation errors remain visible; secured unsaved networks request a password; secret input and command output are handled separately. Confirm/forget flows coordinate with other surfaces.
- **Acceptance criteria:** User can toggle Wi-Fi, discover and connect/disconnect, add or forget a saved connection, and recover from scan/authentication failures without stale competing surfaces.
- **Sources:** `config/quickshell/Wifi.qml`, `config/quickshell/components/wifi.js`, `config/quickshell/menu/WifiLauncher.qml`, `WifiDropdown.qml`, `WifiAddPopup.qml`, `ConfirmPopup.qml`, `config/quickshell/modules/Network.qml`, `config/quickshell/shell.qml`.

### QS-09 — Bluetooth management surfaces

- **Purpose / surface:** Launcher and popup panels.
- **Status:** Implemented and functional; launcher and richer dropdown/add flows coexist.
- **Entry points:** Bar Bluetooth click opens `BluetoothDropdown`; Bluetooth launcher is reachable through Connections and nested kmDot search. Dropdown can open add/confirmation flows.
- **Capabilities:** Enumerates devices, exposes adapter power and discovery, connects/disconnects, pairs unpaired devices, auto-connects after pairing, shows paired/connected state and device-reported battery when available, forgets devices, and supports add-device flow.
- **State/data:** Default adapter state, discovery state, device properties, per-device busy/error state, pairing flow.
- **Dependencies/integrations:** Quickshell Bluetooth service, BlueZ, `BluetoothStore.qml`, `components/bluetooth.js`, launcher/dropdown/add popup and confirmation components. `blueman-applet` remains required as a pairing agent for PIN/passkey-confirming devices.
- **Errors/edge cases:** Adapter/device updates are reactive; pair failure clears pending state; BlueZ device battery is a single device-level value where exposed. No per-earbud component battery support is available in this interface. Radio surfaces coordinate and close each other.
- **Acceptance criteria:** Adapter power and discovery work; device state/actions update; unpaired devices pair then connect; pairing-agent-dependent devices can complete pairing when the agent is running.
- **Sources:** `config/quickshell/BluetoothStore.qml`, `config/quickshell/components/bluetooth.js`, `config/quickshell/menu/BluetoothLauncher.qml`, `BluetoothDropdown.qml`, `BluetoothAddPopup.qml`, `ConfirmPopup.qml`, `config/quickshell/modules/Bluetooth.qml`, `config/quickshell/shell.qml`, `config/hyprland/autostart.lua`.

### QS-10 — Audio output/input controls and media status

- **Purpose / surface:** Top bar entry, popup panel, desktop media state.
- **Status:** Implemented and functional, with a documented device-volume reporting limitation.
- **Entry points:** Bar Audio click opens volume popup; wheel adjusts master output. XF86 audio keys adjust/mute output; XF86 play/pause/next/previous control media players.
- **Capabilities:** Shows now-playing metadata/artwork and media controls; selects output and input devices; controls per-device volume/mute; toggles output mute; shows a live input level while popup is open.
- **State/data:** PipeWire nodes, preferred sink/source, volume and mute, player metadata, mic capture samples.
- **Dependencies/integrations:** Quickshell PipeWire service and object tracking, `playerctl`/MPRIS, `pactl`, `pw-record`, `mic-level.mjs`, `AudioDeviceControl.qml`, `AudioGlyph.qml`, `NowPlaying.qml`, `VolumePopup.qml`.
- **Errors/edge cases:** Filters out stream nodes, cameras, and loopback sources; tracks audio objects before writes; device lists preserve stable ordering. Bluetooth sinks may report 0% despite working audio, and volume writes may not affect them. Capture meter must stop when popup closes and follows default source changes.
- **Acceptance criteria:** Device selection, available controls, mute and media operations work; input list contains hardware audio sources only; meter starts/stops with popup; unsupported Bluetooth volume reporting does not break playback.
- **Sources:** `config/quickshell/modules/Audio.qml`, `config/quickshell/components/AudioDeviceControl.qml`, `AudioGlyph.qml`, `NowPlaying.qml`, `config/quickshell/menu/VolumePopup.qml`, `config/quickshell/scripts/mic-level.mjs`, `config/hyprland/keybinds.lua`.

### QS-11 — Battery information and power profiles

- **Purpose / surface:** Top bar entry and popup panel.
- **Status:** Implemented and functional.
- **Entry points:** Battery bar click; socket `kmdot-battery`.
- **Capabilities:** Presents charge/status, charge rate, estimated time to full/empty, charge history graph, and switches Power Saver/Balanced/Performance profiles.
- **State/data:** UPower battery properties and history; current power profile and performance-profile availability.
- **Dependencies/integrations:** Quickshell UPower/PowerProfiles services; `gdbus` helper `battery-history.sh`; popup socket.
- **Errors/edge cases:** Performance choice is unavailable when the system reports no performance profile. Missing battery/history data should not block bar operation. History output is parsed from UPower’s device object.
- **Acceptance criteria:** Battery status and history refresh while open; available power profiles can be selected; unsupported profiles are not actionable.
- **Sources:** `config/quickshell/modules/Battery.qml`, `config/quickshell/menu/BatteryPopup.qml`, `config/quickshell/components/PillButton.qml`, `config/quickshell/scripts/battery-history.sh`.

### QS-12 — Display arrangement, monitor modes, and brightness

- **Purpose / surface:** Bar entry, popup panel, desktop service.
- **Status:** Implemented and functional; display changes have staged apply/readback and recovery logic.
- **Entry points:** Bar Display click; display popup socket; XF86 brightness keys call `displayBrightness` IPC and show brightness OSD.
- **Capabilities:** Reads monitor inventory/modes; supports extend/mirror/other available layout modes, monitor selection, mode/resolution/position changes, and per-device brightness. Remembers extended layout and persists display settings for subsequent sessions.
- **State/data:** `hyprctl monitors all -j`, monitor capabilities/current state, per-device brightness, cached/persisted layout.
- **Dependencies/integrations:** Hyprland `hyprctl` and `hl.dsp` config evaluation, `brightnessctl`, `DisplayState.qml`, `DisplayPopup.qml`, `modules/Display.qml`, `displayBrightness` IPC, runtime settings file(s).
- **Errors/edge cases:** Changes are serialized/queued and checked against monitor readback; shell recovery is scheduled for risky display changes. External monitor changes require refresh. Physical and logical monitor dimensions/scales differ. Brightness writes coalesce rapid changes.
- **Acceptance criteria:** Available displays and modes are represented from live state; a selected layout applies and is read back; brightness changes converge to the last requested value; Quickshell can recover after display mode transitions.
- **Sources:** `config/quickshell/DisplayState.qml`, `config/quickshell/menu/DisplayPopup.qml`, `config/quickshell/modules/Display.qml`, `config/quickshell/shell.qml`, `config/hyprland/keybinds.lua`, `sync/hyprland.sh`.

### QS-13 — Calendar and agenda

- **Purpose / surface:** Top bar entry and popup panel.
- **Status:** Implemented and functional; event feed is optional.
- **Entry points:** Center clock click; socket `kmdot-calendar`.
- **Capabilities:** Month navigation, date selection, event indicators and day agenda, keyboard day/week/month navigation, periodic and manual event synchronization.
- **State/data:** Selected month/day; parsed events by date; last sync time.
- **Dependencies/integrations:** Optional private iCalendar URL at `~/.config/kmdot/calendar-url`; `curl`; `calendar-sync.sh`; Node `calendar-events.mjs` parser; ICS cache in `~/.cache/kmdot/calendar.ics`.
- **Errors/edge cases:** Missing URL leaves calendar navigation available with no events. Feed fetch is cached for 30 minutes unless forced. Parser handles bounded recurring events, time zones, exclusions, and multi-day all-day entries. Failed fetch retains prior cache where available.
- **Acceptance criteria:** Calendar remains usable without credentials; available feed events appear on correct dates; manual/periodic refresh updates parsed agenda; keyboard navigation crosses month boundaries correctly.
- **Sources:** `config/quickshell/modules/Clock.qml`, `config/quickshell/menu/CalendarPopup.qml`, `config/quickshell/scripts/calendar-sync.sh`, `calendar-events.mjs`, `config/quickshell/shell.qml`.

### QS-14 — Notifications, notification center, and replies

- **Purpose / surface:** Desktop service, transient overlay, notification-center panel, reply popup.
- **Status:** Implemented and functional.
- **Entry points:** Notification server receives desktop notifications; Super+N toggles center; Super+Shift+N toggles DND; bar DND/notification entry; toast actions and reply controls.
- **Capabilities:** Receives notifications, shows transient notifications, tracks live notifications, persists/bounds notification history, groups entries, expands/collapses groups, invokes notification actions, dismisses individual/group/all, opens inline reply where supported, and exposes clear/toggle/DND/dismiss IPC.
- **State/data:** Quickshell notification server tracked notifications, DND state, persistent history, notification group/open state.
- **Dependencies/integrations:** Quickshell `NotificationServer` (actions/body/images/inline reply advertised; markup/hyperlinks/body images/action icons not advertised), notification state file, `DnDState.qml`, Hyprland keybind IPC.
- **Errors/edge cases:** History load failure initializes usable empty history; tracked state is reconciled periodically; opening center clears the unread indicator and dismisses transient toasts. Notification protocol capability limits must be respected.
- **Acceptance criteria:** New notifications reach toast and history; actions/dismiss/reply work when offered; center controls and DND state agree; cleared notifications no longer appear as live.
- **Sources:** `config/quickshell/shell.qml`, `config/quickshell/DnDState.qml`, `config/quickshell/components/NotificationIcon.qml`, `notificationidentity.js`, `config/quickshell/menu/NotificationPopup.qml`, `NotificationCenter.qml`, `NotificationReplyPopup.qml`, `config/hyprland/keybinds.lua`.

### QS-15 — Volume, brightness, and microphone OSDs

- **Purpose / surface:** Transient overlay.
- **Status:** Implemented and functional.
- **Entry points:** Audio and brightness media keys mutate system state then toggle OSD sockets; microphone mute key (XF86AudioMicMute or F4) toggles capture mute then shows mic OSD.
- **Capabilities:** Reflects current output volume/mute, brightness, and microphone mute state after key actions.
- **State/data:** PipeWire/Pulse-compatible sink state, backlight value, default source mute.
- **Dependencies/integrations:** `OSDBase.qml`, three shell OSD instances and socket names; `pactl`, `brightnessctl`/DisplayState, `toggle.sh`, Hyprland media keybinds.
- **Errors/edge cases:** Volume raise is capped at 100%; repeated keys are enabled where appropriate. OSD value is queried from system state after command execution.
- **Acceptance criteria:** Each bound key changes the requested value and presents the matching current-state OSD.
- **Sources:** `config/quickshell/components/OSDBase.qml`, `config/quickshell/shell.qml`, `config/hyprland/keybinds.lua`.

### QS-16 — Native session lock screen

- **Purpose / surface:** Lock screen, including per-screen lock surfaces.
- **Status:** Implemented and functional.
- **Entry points:** Super+L, System → Lock, idle lock via hypridle, `loginctl lock-session`, lockscreen IPC.
- **Capabilities:** Acquires Wayland session lock in the long-lived Quickshell process; presents a lock surface per screen; accepts password and authenticates with PAM; reports errors and transitions to unlock on success. Offers shutdown/restart/suspend controls.
- **State/data:** Lock requested/locked state, password, PAM activity/result, error/unlock transition.
- **Dependencies/integrations:** Quickshell Wayland `WlSessionLock`, `Services.Pam`, PAM config `hyprlock`, Hyprland idle/session commands, `lock-screen.sh`.
- **Errors/edge cases:** Duplicate lock requests are ignored; lock helper starts Quickshell if needed and retries IPC; authentication failure clears password and exposes error state; theme switcher refuses to restart shell while locked. Lock surface must remain owned by long-lived shell.
- **Acceptance criteria:** Session lock is actually acquired before credentials are requested; invalid credentials do not unlock; valid credentials unlock; all screens are covered; key/idle/session entry points converge on the same lock flow.
- **Sources:** `config/quickshell/menu/LockScreenSurface.qml`, `config/quickshell/shell.qml`, `config/quickshell/scripts/lock-screen.sh`, `config/hyprland/keybinds.lua`, `config/hyprland/hypridle.conf`, `theme-switcher/main.sh`.

### QS-17 — Server mode and service control

- **Purpose / surface:** Hidden top bar entry and popup panel; desktop service.
- **Status:** Implemented and functional, subject to Polkit rule installation for privileged system services.
- **Entry points:** Hidden tray server icon/dropdown; `server-mode.sh` CLI.
- **Capabilities:** Toggles server mode; reports mode/inhibitor/Tailscale/Jellyfin status and Tailscale IP; starts/stops services; can manage service controls; suspends selected desktop/background services and processes while active, starts them again when disabled; installs sleep/lid-switch inhibitor. Keeps Handy hidden when restarted.
- **State/data:** Marker/config under user config/cache; user and system service state; inhibitor unit state.
- **Dependencies/integrations:** `server-mode.sh`, systemd user/system, Tailscale, Jellyfin, Docker/containerd and configured background processes; Polkit rule `90-kmdot-server-mode.rules`; shared `serverstatus.js`; quickshell status polling.
- **Errors/edge cases:** Service operations may warn/fail without Polkit rule or installed service; state reflects actual system service status; Handy must be killed/restarted hidden to avoid surfacing its window. Server mode’s sleep inhibition is independent of display DPMS behavior.
- **Acceptance criteria:** Mode transitions update status and inhibitor; configured services/processes stop/start as intended; status identifies failures instead of claiming success; Polkit authorization supports one-click operation after installation.
- **Sources:** `config/quickshell/modules/ServerMode.qml`, `config/quickshell/menu/ServerModeDropdown.qml`, `config/quickshell/components/serverstatus.js`, `config/quickshell/scripts/server-mode.sh`, `config/polkit/90-kmdot-server-mode.rules`, `config/hyprland/hypridle.conf`.

### QS-18 — Attention mode and idle behavior

- **Purpose / surface:** Top bar entry and desktop service.
- **Status:** Implemented and functional.
- **Entry points:** Bar AttentionMode module; hypridle timeout/resume scripts.
- **Capabilities:** Exposes/toggles attention modes used to control idle behavior; idle triggers route to lock, suspend, and display power-off; activity resumes DPMS. Attention mode provides explicit idle command handling.
- **State/data:** Attention mode state/config and current idle action.
- **Dependencies/integrations:** `attention-mode.sh`, `hypridle.conf`, Hyprland DPMS/lock dispatch, server mode sleep inhibitor.
- **Errors/edge cases:** Display-off timeout occurs after lock timeout and before suspend; server mode inhibits suspend but still allows display off. Resume path re-enables DPMS.
- **Acceptance criteria:** Idle actions are consistent with configured mode, lock/suspend/DPMS ordering, and server sleep inhibition; activity restores displays.
- **Sources:** `config/quickshell/modules/AttentionMode.qml`, `config/quickshell/scripts/attention-mode.sh`, `config/hyprland/hypridle.conf`, `config/hyprland/appearance.lua`.

### QS-19 — Handy transcription controls and history

- **Purpose / surface:** Hidden top bar entry, popup panel, launcher, external recording overlay.
- **Status:** Implemented and functional; integrations depend on Handy’s installed app/data files.
- **Entry points:** Super+H opens Handy launcher; hidden bar Handy entry opens rich popup; Super+I invokes Hyprland recording toggle; Handy app may show its recording overlay.
- **Capabilities:** Browse/select local models, persist model selection and restart Handy hidden, inspect transcription history, copy text, retry retained recordings, play/pause audio, edit/save transcription in popup, and delete WAV/database records with confirmation. Launcher provides keyboard-focused model/history actions. Recording toggle begins capture; Enter submits and Escape cancels.
- **State/data:** Handy settings store and history database; model catalog; transcript text; WAV availability; playback/retry/delete state.
- **Dependencies/integrations:** `HandyStore.qml`, `handy-control.mjs`, Handy CLI/app, `~/.local/share/com.pais.handy/{settings_store.json,history.db}`, SQLite, PipeWire/cpal default source, `wl-copy`, Hyprland `toggle_handy.sh` and window rules.
- **Errors/edge cases:** History may outlive WAV files; retry is unavailable then, while delete tolerates missing WAV. Model changes restart Handy hidden. Playback survives switching between launcher and popup and stops after both close. Handy may retain an old per-app PipeWire source route after system-default changes; backend route limitations are documented in AGENTS.md.
- **Acceptance criteria:** Model selection persists and reloads; history actions operate on the selected record; retry requires available audio; deletion removes row/audio and stops playback; switching views preserves active playback; recording key flow submits/cancels.
- **Sources:** `config/quickshell/HandyStore.qml`, `config/quickshell/menu/HandyPopup.qml`, `HandyLauncher.qml`, `config/quickshell/modules/Handy.qml`, `config/quickshell/scripts/handy-control.mjs`, `config/hyprland/scripts/toggle_handy.sh`, `config/hyprland/rules.lua`, `config/hyprland/keybinds.lua`, `config/quickshell/shell.qml`.

### QS-20 — OpenCode and AI-agent usage panels

- **Purpose / surface:** Hidden top bar entry and popup panel.
- **Status:** Implemented and functional when supported CLIs/data are present; optional providers are handled dynamically.
- **Entry points:** Hidden tray OpenCode usage entry; popup socket `kmdot-opencode-usage`.
- **Capabilities:** Displays recent usage, token/cost/activity reports, supports selecting available OpenCode/Codex/Pi providers where detected, and refreshes provider data.
- **State/data:** CLI-specific local usage histories and seven-day aggregated metrics.
- **Dependencies/integrations:** `agent-usage.mjs`, `opencode-usage.mjs`, `opencode stats`, Codex/Pi local session files, Node.js, provider CLI availability.
- **Errors/edge cases:** Providers are discovered from installed executables; missing or malformed provider data should surface an error/empty report without affecting bar operation.
- **Acceptance criteria:** Available providers can be selected and their report loaded; unavailable providers are omitted; empty/missing history is handled gracefully.
- **Sources:** `config/quickshell/modules/OpenCodeUsage.qml`, `config/quickshell/menu/OpenCodeUsagePopup.qml`, `config/quickshell/scripts/agent-usage.mjs`, `opencode-usage.mjs`.

### QS-21 — Display keybind reference

- **Purpose / surface:** Launcher.
- **Status:** Implemented and functional.
- **Entry points:** kmDot menu → Keybinds; launcher socket `kmdot-keybinds`.
- **Capabilities:** Presents parsed Hyprland keybinds in a non-actionable list.
- **State/data:** Current repository keybind definitions and comments.
- **Dependencies/integrations:** `keybinds.lua` plus a Lua shim that stubs the Hyprland DSL; `KeybindsLauncher.qml`.
- **Errors/edge cases:** This view is display-only; malformed or changed keybind definitions may affect parsing.
- **Acceptance criteria:** Current bind definitions are listed accurately and cannot accidentally invoke an action from the reference view.
- **Sources:** `config/quickshell/menu/KeybindsLauncher.qml`, `config/hyprland/keybinds.lua`, `config/hyprland/scripts/keybinds.lua`.

## Shared runtime and integration contracts

- **Surface coordination and IPC:** Shell owns launcher/popup lifecycle and radio-surface coordination. Most launchers/panels expose Unix sockets under `$XDG_RUNTIME_DIR` (fallback `/tmp`) and are toggled by `config/quickshell/scripts/toggle.sh`; Quickshell IPC also exposes `lockscreen`, `displayBrightness`, and `notifications` targets. Notification toasts are intentionally independent of panel exclusion.
- **Startup/deployment:** `sync/quickshell.sh` requires a selected theme, renders palette data, replaces the deployed Quickshell tree under `~/.config/kmdot/quickshell`, links `~/.config/quickshell`, marks shell scripts executable, and may start clipboard watchers. Hyprland autostart starts Quickshell and clipboard history. Quickshell package is installed/removed by repository app configuration.
- **Theme compatibility:** Theme switching is shared with other applications. Quickshell consumes a complete validated role schema from each theme’s `quickshell.conf`; generated `Colors.qml` is deployed only and the hook restarts the shell after writing it. A redesign must preserve the switcher contract while replacing the palette data model only through an approved later phase.
- **Shared dependencies:** Hyprland wallpaper helpers are also used by wallpaper startup/theme switching/SDDM; theme-switcher scripts drive multiple applications; system packages, PipeWire/NetworkManager/BlueZ, clipboard scripts, systemd and PAM are broader workstation integrations. Do not remove them solely because a UI caller changes.
- **Related but out of Quickshell scope:** `config/sddm/themes/kmd-quickshell/` is a separate SDDM login theme, and `config/hyprland/scripts/toggle_handy.sh` creates Handy’s transcription window. They are documented here as integrations, not identified as Quickshell implementation files.

## Partially implemented, referenced, and potentially obsolete items

| Item | Classification | Evidence and audit note |
|---|---|---|
| Bluetooth device-level battery | Partially implemented | UI shows BlueZ’s device-level percentage when available. Per-component earbud/case values are unavailable through the current Quickshell Bluetooth API; see `docs/agents/research/pixel-buds-component-battery.md` if retained in repository. |
| Bluetooth pairing of devices requiring PIN/passkey confirmation | Partially implemented / external dependency | Quickshell exposes pairing but not an agent; successful pairing depends on `blueman-applet` running. |
| Bluetooth sink volume display/write | Partially implemented | BlueZ audio nodes may report zero or ignore writes through the exposed PipeWire volume parameter while playback still works. |
| OpenCode/agent reporting | Partially implemented | Feature depends on optional CLI installation and local provider-specific data formats; provider list is dynamic. |
| Calendar events | Implemented with optional integration | Calendar shell works without a feed; event data requires a private URL file and network fetch. |
| Quickshell brightness popup | Referenced but not implemented in current tree | User-provided AGENTS.md describes `menu/BrightnessPopup.qml` and a brightness popup socket, but neither file nor `modules/Backlight.qml` exists in the audited `config/quickshell/` tree. Actual tree provides display brightness management in `DisplayState.qml`/`DisplayPopup.qml` and brightness OSD. Confirm whether a separate brightness popup was intended before design scope is frozen. |
| `config/quickshell/components/NotificationIcon.qml`, `notificationidentity.js`, `R1Icon.qml`, `r1icons.js`, `WifiIcon.qml`, `BluetoothStore.qml` | Implemented and in active use | Reference tracing found consumers in notification surfaces, icon components, Wi-Fi dropdowns, Bluetooth flows, and volume controls. They are shared implementation dependencies, not dead code. |
| `config/quickshell/Wifi.qml` plus launcher Wi-Fi state | Potential overlapping implementation | Current shell instantiates both shared `Wifi.qml` state (dropdown/add flows) and `WifiLauncher.qml` logic (launcher flow). Both manage NetworkManager; behavior is present in both, so consolidation is a design/implementation decision, not grounds to drop capabilities. |
| `WifiDropdown`/`BluetoothDropdown` add flows alongside launchers | Potentially overlapping UX | Both systems are instantiated and reachable by bar/Connections paths. Confirm which flows remain required; inventory preserves both pending approval. |
| Lock screen login screen | Implemented lock surface; no Quickshell login screen | Session lock is implemented in Quickshell. SDDM login is a separate application/theme under `config/sddm/`, not part of the Quickshell UI inventory. |

## Unresolved decisions for approval

1. Should the separate brightness popup described in the supplied AGENTS.md but absent from the repository be included in the redesign, or should brightness remain represented by the current display controls and OSD?
2. Should both Wi-Fi/Bluetooth launcher and dropdown/add flows be preserved as independent entry paths, or should the later design phase propose one unified interaction per radio while retaining the full capability set?
3. Should the standalone Quickshell session lock surface be included in the FigCraft design scope, given that it is a security-critical surface and the current implementation uses native Wayland session lock plus PAM?
4. Are the optional OpenCode/AI usage panels, notification reply flow, and Handy history editing/deletion all approved feature scope, or should any be marked for possible retirement? No feature is removed by this inventory.

## Repository traceability index

Primary implementation roots: `config/quickshell/shell.qml`; `config/quickshell/modules/`; `config/quickshell/menu/`; `config/quickshell/components/`; `config/quickshell/scripts/`; `config/quickshell/{DisplayState,DnDState,HandyStore,Wifi,BluetoothStore}.qml`. Integration roots: `config/hyprland/{keybinds.lua,autostart.lua,hypridle.conf,rules.lua,env.lua}`; `config/hyprland/scripts/`; `sync/quickshell.sh`; `theme-switcher/{main.sh,hooks/quickshell.sh,render-quickshell.sh,quickshell.roles}`; `themes/*/quickshell.conf`; `config/polkit/90-kmdot-server-mode.rules`; `install.sh`; `config-install.sh`; `config-uninstall.sh`; `sync/sddm.sh`; `config/sddm/`.
