# Quickshell stability audit

Audit date: 2026-11-04. This was a static and read-only runtime investigation. No graphical session, Quickshell instance, compositor, audio service, display mode, or theme was started, stopped, or changed.

## Diagnosis

The available evidence confirms recurring **Quickshell process crashes**, but does not establish a single cause for the recent severe machine freeze. It does not show a Hyprland crash, a kernel OOM kill, or an i915 GPU hang in the available journal search. A hard lock can leave no final journal record, so those absences do not rule out a kernel or GPU stall.

There is a strong, independently reported Quickshell 0.3.1 failure mode that matches the freeze symptom: when WirePlumber/PipeWire restarts, Quickshell's PipeWire event loop can spin on an invalid socket, emit errors continuously, and grow CPU, memory, and logs until the shell becomes unusable. The current installation is Quickshell 0.3.1, Qt 6.11.2, Hyprland 0.56.2, PipeWire 1.6.9, WirePlumber 0.5.17, and Intel i915. The upstream report includes independent reproduction on Quickshell 0.3.1, Qt 6.11.2, Hyprland 0.56.2, PipeWire 1.6.9, and i915, and another report describes the same failure on 0.3.2. This is a close environment match, but local logs do not prove WirePlumber restarted at the time of the freeze. See [upstream issue #1052](https://github.com/quickshell-mirror/quickshell/issues/1052).

The System Monitor itself is not supported by the source evidence as the cause of a full machine freeze. Its work is small and bounded: shared CPU/memory sampling every two seconds while at least one bar indicator or the popup needs it; per-thread `/proc/stat` sampling every second only while the popup is open; and a six-row `top` query every three seconds, with one process at a time and refreshes coalesced. Disabling both indicators still leaves popup sampling enabled while the popup remains open. No path in these transitions restarts Quickshell. The persisted state file currently says `cpuEnabled: false`, `memEnabled: true`, so both indicators were not disabled in the last successfully persisted settings.

## Evidence collected

- Repository root: `/home/kedarmd/dev/kmDot`; branch `main`; HEAD `9a4326c6a81b30b6551df591c037b67e456d3bfb`.
- Existing uncommitted changes were present before edits and have been preserved. In particular, the existing `autostart.lua` change removing unconditional `hex start` was not overwritten.
- Deployed paths: `~/.config/quickshell` is a symlink to `~/.config/kmdot/quickshell`; `~/.config/hypr` is a symlink to `~/.config/kmdot/hyprland`.
- Before editing, the deployed Quickshell and Hyprland trees were archived to `/tmp/kmdot-quickshell-audit-20261104T145251Z.tar.gz`, SHA-256 `c328f7722b49e90a7812b761f6246415dd9cee48b4fc25de2a19d0487ccdec58`.
- Installed versions: Quickshell `0.3.1-1.1`, Hyprland `0.56.2-3.1`, Qt base/declarative `6.11.2`, PipeWire `1.6.9-1`, WirePlumber `0.5.17-2.1`.
- Thirteen Quickshell crash report directories exist under `~/.cache/quickshell/crashes/`, from 2026-08-20 through 2026-10-22. These are Quickshell's own reports; `coredumpctl list` reports no systemd coredumps.
- Six older Quickshell 0.3.0 reports share a `QQmlListModel::data()` stack. Their logs include repeated `_ref is null` warnings while notification history was being written. This makes native notification objects stored in toast `ListModel` roles a credible, actionable lifecycle defect; it does not prove every one of those crashes came from notifications.
- Quickshell 0.3.1 reports include an abort in `QWindow::unsetCursor()` during `QQuickItem` teardown and a SIGSEGV in `QInputMethod::commit()` during focus-scope teardown. Two other reports point through Wayland proxy calls during QObject destruction in a separate `/home/kedarmd/dev/oma-cast` config. These stacks establish shell/native UI teardown crashes, but do not identify a specific kmDot QML component.
- Some crash logs end with `Exiting due to IPC request`; one report contains a configuration reload where QML files were missing at `~/.config/quickshell` during the reload. This is consistent with the old delete-then-copy sync window and confirms that deployment must not remove the active directory before a replacement has been prepared.
- The available kernel journal search returned no OOM kill or i915 GPU hang record. It does confirm Intel i915 hardware. A pre-existing uncommitted autostart comment says Hex had recorded i915 GPU hangs on Nov 1; that is preserved user context, not a reproduced finding from the logs available here.
- The sandbox cannot connect to the user systemd bus and cannot see the active graphical session. Runtime service ownership, current process trees, live RSS/CPU, and current PipeWire restart history remain unverified. No graphical-session validation was attempted.
- The repository's `toggle.sh` and deployed `toggle.sh` differed: the deployed script still had the restart-on-missing-socket implementation. Therefore, the source fix in this audit is not active until an authorized deployment.

## Architecture and lifecycle inventory

`shell.qml` is one Quickshell `Scope`. It constructs the notification server, lock surface, popup/launcher objects, shared state singletons, and root IPC handlers at startup. Bar windows and lock/reveal surfaces are `Variants` over `Quickshell.screens`, so bar modules are per-screen. Most popup state and timers are single instances in the shell scope. Popup socket servers are active even while their surfaces are closed.

| Owner | Current behavior | Cost and lifecycle notes |
|---|---|---|
| `SystemStatsState.qml` | One 2s CPU/memory timer when a bar indicator or monitor popup needs data; 1s thread timer only while the popup is open. | Singleton shared across screens. Each process is guarded against overlap. |
| `SystemMonitorPopup.qml` | `top-processes.sh` every 3s while open. | One `top` process at a time; a pending refresh is coalesced. Closing clears the pending request; one already-running bounded sample may finish. |
| `modules/Battery.qml` | Bash sysfs adapter scan every 1s. | Per-screen instance, so multiple monitors duplicate a small process scan. Native UPower supplies the rest. |
| `modules/ServerMode.qml` | Status script every 2s while its popup is closed. | Per-screen process polling; no shared state singleton currently owns it. |
| `modules/Bluetooth.qml` | Device/adapter refresh every 2s. | Per-screen timer; reads native Bluetooth objects and spawns no process. |
| `modules/Workspaces.qml` | Current working tree has a 1s `hyprctl`/`jq` snapshot plus a 50ms event debounce. | Per-screen process polling. The event path makes the view responsive; the 1s snapshot heals missed events. This is an existing uncommitted user change, left intact. |
| `DisplayState.qml` | Backlight query every 700ms; monitor list every 4s while Display is open. | Singleton; the backlight process is non-overlapping. The 700ms child-process cadence is relatively high. Monitor changes use a serialized command/readback sequence. |
| `DisplayColorState.qml` | Shader/state refresh every 4s. | Singleton worker serializes refresh and apply operations. The refresh timer now runs only while Display is open; opening still performs an immediate refresh. The shader script validates selected outputs and only reapplies when state changes. |
| `components/NowPlaying.qml` | MPRIS player/position refresh every 1s. | Native service only, but it previously ran while the Volume popup was hidden. It now runs only while Volume is open. |
| `CalendarPopup.qml` | Instantiated at shell startup; sync on startup/open and periodic 30m refresh. | ICS fetch uses curl with a 25s timeout. The periodic Timer was present but disabled; it is now enabled, and concurrent sync requests are rejected. |
| `NotificationPopup.qml` | 100ms remaining-time tick only while toast cards are open. | Bounded to three cards; appropriately gated. Toast model now retains scalar fields and notification IDs only. |
| `NotificationCenter.qml` | 3s live-notification reconciliation only while the center is open. | History is capped at 100 records and persisted through FileView. A notification storm can still cause repeated async history writes. |
| `VolumePopup.qml` / `HexHud.qml` | `pw-record` microphone capture while Volume is open / Hex is recording. | Child Node script handles normal termination, closes `pw-record`, and reports meter samples around every 80ms. The two surfaces can capture simultaneously. Abrupt Quickshell termination behavior still needs runtime validation. |
| Clipboard daemon | Two long-lived `wl-paste --watch` children, text and PNG. | Started by Hyprland autostart, outside Quickshell. Startup is now serialized with a cache-directory flock; existing `pgrep` guard remains. Normal signals kill the watcher children. SIGKILL orphan behavior remains a concern; history was not read or changed. |
| `DisplayColorState.qml` / display control | `hyprctl` monitor and shader reads; `hyprctl eval` only for explicit user changes. | No display mode, assignment, or shader was changed during this audit. Display mode changes can schedule one delayed shell recovery process, described below. |
| Launcher plugin | Desktop source and JSON stores use FileView watchers; calculator currency uses XHR with a 15s timeout; backend has a short 30ms debounce. | Most search/ranking is synchronous JavaScript over in-memory indexes. OpenCode usage is started in an external QML `Process`; its Node utility uses synchronous child execution and has no command timeout. It cannot block the QML thread, but can continue consuming a child process after the popup closes. |

`HexHud.qml` owns a timer while recording and starts/stops its meter through `Process.running`. Its destruction handler also attempts to execute the Hyprland Escape-unbind script. The component is still alive during `Component.onDestruction`, but whether that child completes during process teardown is not provable without a live-session lifecycle test. Startup already resynchronizes the binding. This remains a pending teardown check.

## Confirmed changes

1. `config/quickshell/scripts/toggle.sh` no longer kills or starts Quickshell when a popup socket is absent or stale. It reports a missing/unavailable socket and exits with status 1. Ordinary popup interactions can no longer trigger a shell-wide restart.
2. `sync/quickshell.sh` now stages and checks the full config before promotion, refuses to overwrite unexpected real directories/symlinks, serializes syncs, keeps a timestamped backup, and restores the previous tree on a failed promotion. It no longer `rm -rf`s the deployed Quickshell directory before copying. The sync script was not run.
3. Notification toast and reply UI no longer store a native Notification or action object in `ListModel` roles. They retain scalar IDs, resolve the current tracked notification when needed, and omit the unused image payload. This directly addresses the `_ref is null` / `QQmlListModel::data()` warning pattern without changing presentation or action behavior.
4. Calendar sync requests no longer overlap, and the documented 30-minute timer now runs.
5. The clipboard daemon's startup check is protected by `flock`, preventing concurrent autostart invocations from passing the old `pgrep` check together.
6. `dictation-provider.service` now invokes its supervisor's `stop` action when the unit stops. The unit was not reloaded, enabled, started, or stopped.
7. The hidden Volume popup no longer polls MPRIS once per second; its timer is active only while the popup is open. The OpenCode busy spinner now animates only while its popup is open and loading. Display color polling likewise runs only while the Display popup is open.
8. A temporary `tests/quickshell-toggle.sh` checked that a missing socket reports an error without shell restart commands, that notification list roles remain scalar, and that System Monitor's shared-consumer and non-overlap guards remain present. The script was later removed to follow this repository's no-test convention; these checks are historical validation, not a maintained test suite.

## Other confirmed risk areas

- Restart paths remain separate from ordinary popup toggles. `theme-switcher/hooks/quickshell.sh` intentionally `pkill`s and starts Quickshell after a theme change; it has no shared restart lock, and output is suppressed. `DisplayState.qml` starts a delayed detached recovery after explicit layout-mode changes that may remove every output; repeated mode changes could schedule more than one recovery helper. `scripts/lock-screen.sh` can start Quickshell with `--no-duplicate` if lock IPC is unavailable. These paths were read, never executed. Future work should centralize or serialize intentional restarts and log failures.
- `sync/quickshell.sh` still performs provider service configuration/restart and may start clipboard watchers after installing the staged tree. The complete sync path must be reviewed in an isolated HOME before deployment; it was not executed here.
- The current Hyprland autostart source and deployed file both launch Quickshell and the clipboard daemon. The repo's existing uncommitted change has removed unconditional `hex start`. `dictation-provider.sh` is intended to own provider selection, but actual `systemctl --user` state and process ownership could not be checked.
- Per-screen Battery, ServerMode, Bluetooth, and Workspaces timers duplicate work on multi-monitor setups. Battery and ServerMode spawn external commands; Workspaces' current user-modified implementation runs one `hyprctl`/`jq` snapshot per screen each second. A shared per-session state owner would reduce process churn, but requires dedicated regression coverage before changing these paths.
- `DisplayState.qml` polls backlight every 700ms; `DisplayColorState` is now popup-gated. The 700ms polling interval could be raised, but would affect how quickly bar brightness reflects keyboard-driven changes and needs interactive validation.
- `scripts/clipboard-capture.sh` serializes history writes and bounds clipboard reads, but image thumbnail generation has no timeout or payload-size cap. It runs outside Quickshell. Existing history was preserved.
- `agent-usage.mjs` / `opencode-usage.mjs` use synchronous child-process calls without a timeout. QML launches them asynchronously, so this is not a main-thread block, but a hung CLI can leave a worker running.
- `NotificationCenter.saveHistory()` can issue one async FileView write per history mutation. The 100-record cap bounds serialization size, but a burst can queue repeated writes. No evidence ties this to the newer 0.3.1 teardown crashes.

## Validation and limits

Executed read-only checks and local tests:

- The temporary `tests/quickshell-toggle.sh` passed before it was removed to follow this repository's no-test convention. It used fake commands and a temporary runtime directory; it did not connect to Quickshell or alter user state.
- `bash -n` passed for the modified shell scripts and the temporary test script.
- The `qmllint` and `qmlformat` found first on `PATH` were Qt 5.15 tools from `qt5-declarative`, while the shell runs Qt 6.11.2. They silently failed (`qmllint` exit 255, `qmlformat` exit 1) on `shell.qml` and `SystemStatsState.qml`; this was a validator-version mismatch, not evidence those files were valid. The matching Qt 6.11 tools at `/usr/lib/qt6/bin` successfully parsed and formatted both files. Qt 6 `qmllint` returned 0 for both, with static-analysis warnings (including unresolved project singletons/types and `FileViewAdapter`); these warnings need a Quickshell-aware runtime/tooling pass before being treated as source defects.
- `quickshell --help` and `quickshell --version` were read-only; no shell instance was launched.
- `git diff --check` is included in the final source review.

Not run because the user explicitly protected the graphical session: QML runtime loading, notification replacement/expiry stress, System Monitor toggle transitions, PipeWire/WirePlumber restart reproduction, microphone capture teardown, display hotplug/mode/shader tests, theme switch, sync/deploy, or a second Quickshell instance. These require an isolated graphical test session or explicit approval for a later live-session validation window.

## Deployment comparison and safe procedure

The deployed `~/.config/quickshell` symlink points to the real directory `~/.config/kmdot/quickshell`; `~/.config/hypr` points to `~/.config/kmdot/hyprland`. A recursive comparison found the expected generated deployed-only `Colors.qml` plus the Quickshell files changed by this audit. No deployed-only source file or other unique local Quickshell customization was found. Preserve the generated palette by rendering the currently selected `catppuccin` theme into the staged tree. Hyprland was not modified by this audit.

The pre-edit archive `/tmp/kmdot-quickshell-audit-20261104T145251Z.tar.gz` passed `sha256sum` verification (`c328f7722b49e90a7812b761f6246415dd9cee48b4fc25de2a19d0487ccdec58`) and `tar -tzf` integrity checking. It contains both `quickshell/` and `hyprland/`. Keep it as the independent recovery copy.

### Deployment record

Controlled Quickshell-only deployment completed on 2026-11-04 at 22:19 local time from TTY. The matching-source hash gate, Qt 6 staged QML checks, generated Catppuccin palette comparison, and no-running-Quickshell gate passed. No service command, Quickshell launch, compositor command, display operation, or audio operation was run.

- Active config: `~/.config/kmdot/quickshell`; `~/.config/quickshell` still resolves to it.
- Immediate rollback directory: `~/.config/kmdot/quickshell.backup.20261104T221915`.
- Persistent pre-deployment tree snapshot: `~/.local/state/kmdot/backups/quickshell-deployed-20261104T221915`.
- Persistent verified audit archive: `~/.local/state/kmdot/backups/kmdot-quickshell-audit-20261104T145251Z.tar.gz`.
- Post-deployment comparison found only generated `Colors.qml` in addition to repository files; its content matches the `catppuccin` palette rendered before staging.
- Quickshell remains stopped and the laptop remains in TTY. No graphical test has been started.

Do not use `sync/quickshell.sh` for this QML-only deployment: in addition to copying Quickshell, it can disable/restart dictation-provider services and start clipboard watchers. The following staging procedure records how the activation was performed; do not rerun it unless planning another deployment. It does not invoke Quickshell, Hyprland, systemd, theme hooks, or display commands. It refuses to replace files while a Quickshell process is still present.

```bash
cd /home/kedarmd/dev/kmDot
set -euo pipefail

if pgrep -x quickshell >/dev/null; then
  echo 'Quickshell is still running; do not replace its files yet.' >&2
  exit 1
fi

current="$HOME/.config/kmdot/quickshell"
link="$HOME/.config/quickshell"
theme="$(cat "$HOME/.cache/kmdot_theme")"
stamp="$(date +%Y%m%dT%H%M%S)"
stage="$(mktemp -d "$HOME/.config/kmdot/.quickshell-stage.XXXXXX")"
backup="$HOME/.config/kmdot/quickshell.backup.$stamp"
cleanup() { [[ -z "${stage:-}" || ! -d "$stage" ]] || rm -rf -- "$stage"; }
trap cleanup EXIT

[[ -L "$link" && "$(readlink -f "$link")" == "$current" ]]
[[ -d "$current" && ! -e "$backup" ]]
cp -a config/quickshell/. "$stage/"
./theme-switcher/render-quickshell.sh "themes/$theme/quickshell.conf" > "$stage/Colors.qml"
chmod +x "$stage/scripts/"*.sh "$stage/launcher/bin/"*
find "$stage/scripts" -maxdepth 1 -name '*.mjs' -exec chmod +x {} +

for file in shell.qml SystemStatsState.qml; do
  /usr/lib/qt6/bin/qmlformat "$stage/$file" >/dev/null
  /usr/lib/qt6/bin/qmllint -I /usr/lib/qt6/qml -I "$stage" "$stage/$file"
done

mv -T -- "$current" "$backup"
if ! mv -T -- "$stage" "$current"; then
  mv -T -- "$backup" "$current"
  exit 1
fi
stage=''
trap - EXIT
printf 'Installed Quickshell config. Rollback copy: %s\n' "$backup"
```

The symlink remains pointed at the same path. The old directory is moved aside before the staged directory takes its place, so the path has a brief gap; this procedure is for a TTY with no Quickshell process running. If promotion fails, it restores the old directory. To roll back later from a TTY, replace the backup value with the printed path:

```bash
current="$HOME/.config/kmdot/quickshell"
backup="$HOME/.config/kmdot/quickshell.backup.YYYYMMDDTHHMMSS"
failed="$HOME/.config/kmdot/quickshell.failed.$(date +%Y%m%dT%H%M%S)"
mv -T -- "$current" "$failed"
mv -T -- "$backup" "$current"
```

For the first graphical login, keep the remote TTY/SSH reachable and leave the TTY available. Let the session start normally, then inspect Quickshell and system logs before opening System Monitor. If Quickshell freezes while the TTY remains responsive, first capture `journalctl --user -b --since '-10 minutes'`, `journalctl -k -b --since '-10 minutes'`, `ps -eo pid,ppid,rss,%cpu,etime,args --sort=-rss`, and the newest directory under `~/.cache/quickshell/crashes`. If those show a wedged Quickshell process, terminate only the verified Quickshell PID with `kill -TERM <pid>`; do not restart Hyprland or PipeWire as the first recovery step. If the whole machine no longer responds to TTY or SSH, there is no safe in-session recovery command; preserve any remaining evidence and use the machine's normal forced-recovery path only as a last resort.

### Prepared first graphical test (not run)

The active deployed Hyprland autostart file is `~/.config/kmdot/hyprland/autostart.lua`. Its only Quickshell launch is `hl.exec_cmd("quickshell &")`; it does not launch Hex. When ready to test, temporarily comment out that one line while keeping an exact backup:

```bash
set -euo pipefail
autostart="$HOME/.config/kmdot/hyprland/autostart.lua"
stamp="$(date +%Y%m%dT%H%M%S)"
autostart_backup="$HOME/.local/state/kmdot/backups/hyprland-autostart.$stamp.lua"
cp -a "$autostart" "$autostart_backup"
sed -i 's|^[[:space:]]*hl.exec_cmd("quickshell &")$|    -- TEMP: Quickshell disabled for controlled first-login test|' "$autostart"
grep -n 'TEMP: Quickshell disabled' "$autostart"
```

Log into Hyprland normally through the graphical login. Do not start Quickshell yet. Confirm the compositor and other desktop basics work. In Ghostty, start Quickshell in the foreground with persistent verbose logging:

```bash
set -o pipefail
log="$HOME/.local/state/kmdot/quickshell-first-login.log"
quickshell --path "$HOME/.config/quickshell" -vv 2>&1 | tee -a "$log"
```

Use another terminal for ongoing measurements and checks. Capture the PID once Quickshell starts:

```bash
pid="$(pgrep -xo quickshell)"
watch -n 2 "ps -p $pid -o pid,ppid,rss,%cpu,etime,args; printf 'direct children: '; ps --no-headers --ppid $pid | wc -l"
```

In a separate terminal, watch PipeWire/WirePlumber logs without restarting either service:

```bash
journalctl --user -f -u pipewire.service -u wireplumber.service
```

Also inspect the captured Quickshell log for QML errors, binding loops, repeated socket errors, and PipeWire warnings. Compare CPU and RSS over several minutes at idle, after opening and closing the System Monitor, and after each feature check. A rising RSS trend, sustained high CPU, or repeated PipeWire socket/loop errors is a stop signal; return to TTY and collect evidence before terminating the verified Quickshell PID.

Exercise the System Monitor with both bar indicators visible; disable CPU then memory while the popup remains open; verify values continue updating; close the popup and verify thread/process sampling stops; reopen it and verify sampling resumes. Restore the original persisted bar visibility (`CPU hidden`, `memory visible`) after the check. Then test a notification and replacement (`id=$(notify-send --print-id 'kmDot test' 'first')`, followed by `notify-send --replace-id "$id" 'kmDot test' 'replacement'`), the launcher with Super+Space, and the audio popup. Do not test display mode/shader changes or deliberately restart audio services during this session.

After stability is demonstrated, restore the exact original autostart file so normal future sessions launch Quickshell:

```bash
cp -a "$autostart_backup" "$HOME/.config/kmdot/hyprland/autostart.lua"
```

If the graphical test fails, return to TTY, capture logs and process state, then stop only the manually started Quickshell process after verifying its PID. Restore the deployed configuration using the immediate rollback path recorded above. Leave the temporary autostart disabled until the cause is understood; restore it from `"$autostart_backup"` only when the next login should launch Quickshell again.

After login is stable, test the System Monitor in this order: open it with both indicators visible; disable CPU and then memory; verify the popup continues updating; close it and verify the expensive thread/process samplers stop; reopen it and verify sampling resumes; restart neither service nor shell during this check. Runtime success remains pending until this is performed by the user in the graphical session.

The current installed Quickshell is 0.3.1. Upstream lists 0.3.2 as released, but the PipeWire issue has reports reproduced on 0.3.2, so a package update alone is not a verified fix. Do not restart WirePlumber/PipeWire or Quickshell as a diagnostic in the protected session. Record the timestamp and inspect Quickshell's crash directory, journal, and systemd cgroup before any future recovery action.

## Controlled runtime follow-up (2026-11-05)

The user rebooted after the temporary touchpad investigation; the built-in touchpad then worked. In the next controlled Hyprland session, the temporary autostart remained active: Quickshell had no automatic startup, `pgrep -a -x quickshell` returned no process, and `hypridle.service` was inactive. The user manually started Quickshell with persistent verbose logging at `~/.local/state/kmdot/quickshell-first-login.log`.

The user repeated the System Monitor visibility scenario that had previously preceded a freeze. It completed successfully; no crash or freeze reproduced. This is one successful run, not proof that the intermittent failure is resolved. The user has not yet provided CPU/RSS measurements or a PipeWire/WirePlumber journal excerpt.

The notification replacement test did not update the displayed history row: `notify-send --print-id` returned ID 7 and the replacement command exited 0, but the notification center continued to show the original “before” body as a separate history item. The filtered Quickshell log showed successful notification-server registration, no `_ref is null`, QML binding-loop, or PipeWire messages in the supplied excerpt, and repeated `QLocalSocket::PeerClosedError` warnings. Those socket warnings are consistent with the configured one-shot popup IPC clients connecting and closing; they did not accompany a reported crash.

The replacement behavior is explained by the installed Quickshell 0.3.1 source: `NotificationServer::Notify` updates the existing tracked `Notification` object in place when `replacesId` resolves, and emits the `notification` signal only for a new notification. kmDot's `shell.qml` previously refreshed its scalar toast and history snapshots only in `onNotification`, so in-place replacements remained stale. The source now listens to tracked notification property-change signals and coalesces them into a refresh of the toast and history rows. See the [Quickshell 0.3.1 notification server implementation](https://github.com/quickshell-mirror/quickshell/blob/v0.3.1/src/services/notifications/server.cpp#L163-L203).

Before the temporary test script was removed to follow this repository's no-test convention, regression coverage was extended there to assert replacement-property listeners, scalar snapshot updates, and the history upsert path. `bash tests/quickshell-toggle.sh` and `git diff --check` passed at that time, including Qt 6 `qmlformat`/`qmllint` checks for the touched QML files. The replacement fix exists in the repository only; it has not been deployed or exercised in the live session. The deployed shell remains the version used for the successful System Monitor test.

Next controlled-session steps: finish observing the current run and test the audio popup without restarting PipeWire/WirePlumber; capture CPU/RSS and relevant logs. Do not restore normal autostart until the user is satisfied with the manual-session checks. The repository-only notification replacement fix requires a later approved deployment and a live replacement retest.

## Controlled deployment and runtime validation (2026-11-05 02:28 IST)

On the user's request to complete the remaining validations, the current repository Quickshell tree was staged with the selected `catppuccin` palette and Qt 6 checked before activation. Before deployment, only `shell.qml` and `menu/NotificationPopup.qml` differed from the deployed Quickshell source; no deployed-only source customization was found. The active Quickshell PID 6626 exited cleanly on SIGTERM. The staged tree was promoted while no Quickshell process was running, and the previous tree was retained at `~/.config/kmdot/quickshell.backup.20261105T021554`. The `~/.config/quickshell` symlink still resolves to `~/.config/kmdot/quickshell`. The full `sync/quickshell.sh` was not used, so the dictation-provider service and clipboard watchers were not restarted.

The deployed Quickshell was manually restarted as PID 386807 with verbose output appended to `~/.local/state/kmdot/quickshell-first-login.log`. Live checks completed:

- Sent a notification and replaced it by ID. The notification history contained one row for the ID with the replacement body, and a screenshot of the visible toast showed the replacement body. This also exercised the queued property-change lookup against the tracked notification.
- A normal-urgency test toast was visible immediately and absent from the next screenshot after its five-second timeout; its history entry remained.
- With DND temporarily enabled through the watched state file, replacing an already visible toast left its existing body unchanged, and a new notification did not produce a toast. Both notification bodies were still written to history. The original `dnd-state.json` content was restored; because `cp -a` preserved its older timestamp and the live file watcher did not refresh immediately, touching the restored file triggered reload. The bar returned to its original unslashed bell and the persisted state is `dndEnabled: false`.
- Opened and closed the System Monitor, Volume popup, and app launcher through their IPC sockets. Screenshots showed the System Monitor's CPU, per-thread, memory, and process data; the Volume popup's output and input devices; and the launcher suggestions. No audio or display control was changed.
- The persisted stats state was `cpuEnabled: false, memEnabled: false`. While the System Monitor remained open, the watched state file was temporarily changed to true/true and then false/false. The bar segments appeared and disappeared, while the popup continued displaying changing CPU/thread values and process data with both indicators disabled. Reopening the popup refreshed the data. The exact original stats state file was restored. This exercised the shared state and polling gates, but not the buttons' pointer click handlers.
- Process gating was checked with the popup closed and open: the `system-stats` and `thread-stats` runtime cache mtimes advanced while open, then remained unchanged for three seconds after close. A short `/proc` scan also observed `top-processes.sh` while open and no occurrences after close.
- PipeWire and WirePlumber remained active. `journalctl --user` had no entries for either service in the ten-minute check window; neither service was restarted.
- No new Quickshell crash directory appeared. The runtime log showed no `_ref is null`, binding-loop, or PipeWire errors. `QLocalSocket::PeerClosedError` warnings followed one-shot IPC clients closing. Other observed warnings were `PopupWindow` width/height deprecations in the unchanged `DictationProviderDropdown.qml` and two Qt SVG invalid-path warnings; these were not investigated further.
- RSS rose during startup and popup loading, then stayed between 292,172 and 293,104 KiB over a 30-second observation. `ps` average CPU was 6.3–6.5% over the final samples; the active Ghostty window title was changing during the check, so this is not an idle baseline.

The live check did not stress-test notification expiry, restart PipeWire/WirePlumber, or change display/audio controls. The bar-visibility state is restored to false/false and DND is restored to false. Five temporary `notify-send` test notifications (IDs 1–5) remain in notification history. The Quickshell process is left running with the deployed repository tree; the rollback copy remains available at the path above.
