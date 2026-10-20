# Quickshell session lock and SDDM greeter plan

Status: **LOCKSCREEN-01 rev 4 is implemented and deployed. User confirmed the repaired lockscreen works and the SDDM logo rendering fix works on 2026-10-13.** The login-screen load errors were repaired and the new greeter loads without QML errors or embedded-theme fallback. The earlier installation-pending notes are superseded.

## Current implementation — 2026-10-13

- Quickshell owns the native Wayland session lock in its long-lived shell process. Per-screen UI lives in `config/quickshell/menu/LockScreenSurface.qml`; PAM state and lock IPC live in `config/quickshell/shell.qml`. Authentication uses the installed `hyprlock` PAM service; the package remains installed although the old screen configs were removed.
- Super+L, System → Lock and Hypridle route through `config/quickshell/scripts/lock-screen.sh`. Hypridle uses `inhibit_sleep = 3` and `loginctl lock-session` before suspend. Preserve Attention mode's idle gating.
- `theme-switcher/main.sh` refuses theme switching while Quickshell holds the lock, preventing its normal restart from killing the lock owner. Check `quickshell ipc call lockscreen isLocked` before a manual restart or sync affecting the lock UI.
- SDDM's separate greeter lives in `config/sddm/themes/kmd-quickshell/Main.qml`. It uses SDDM user/session models, login/power callbacks and the approved external Desktop session selector. The lockscreen and greeter share visual design, not authentication objects.
- `theme-switcher/hooks/sddm.sh` writes the palette to `/var/tmp/kmdot-sddm-theme.conf`; installed `theme.conf.user` links there. Both screens use `/var/tmp/kmdot-current.png` for the selected wallpaper. The SDDM logo rasterizes its SVG at displayed physical size using `sourceSize: Qt.size(width * Screen.devicePixelRatio, height * Screen.devicePixelRatio)`, matching `R1Icon.qml`.
- Quickshell and Hyprland were synced and restarted/reloaded. The user completed the privileged SDDM sync and subsequently confirmed the logo fix works. Future SDDM source changes require `./sync/sddm.sh` from a sudo-authenticated terminal and take effect on the next greeter start; restarting SDDM ends the current desktop session.

## Repairs and verification

- **Password rejected:** the PAM response handler read `lockPassword.text`, but `lockPassword` is a string alias. A focused handler check reproduced PAM receiving `undefined`. Response, completion and lock-entry handlers now use `lockState.password`; checks verified credential delivery, clearing on both outcomes and unlocking only on success. User confirmed correct-password unlock works.
- **Default greeter:** `/etc/sddm.conf` retained `kmd-hyprlock` and overrode `/etc/sddm.conf.d/kmdot.conf`. SDDM's journal confirmed it selected the missing old theme and fell back. `sync/sddm.sh` now authenticates first, installs the new theme, migrates explicit theme keys in the higher-precedence file while preserving unrelated settings, backs up the original to `/etc/sddm.conf.kmdot-backup`, and removes the old theme last. The migration check preserved unrelated configuration.
- **Greeter failed at line 174:** `Non-existent attached object` came from unqualified `ScrollIndicator.vertical` with an aliased Controls import. Both pickers now use `Controls.ScrollIndicator.vertical`. Further runtime checks exposed unsupported `userModel.get()` and invalid Column child anchors. User selection now uses ComboBox `textAt()`/`find()`; the greeter power controls wrap the Column and overlay MouseArea in an Item. The separate Quickshell lock surface had the same invalid child-anchor pattern; its power actions were repaired as stable item delegates and revalidated with `qmllint`.
- **Blurry greeter logo:** the SVG lacked an explicit rasterization size. Added QtQuick.Window and the same screen-scale-aware `sourceSize` binding as the lockscreen renderer. The user confirmed the result works.
- **Preview lesson:** SDDM sends diagnostics to the journal. Empty stdout/stderr in the original preview hid the QML error and embedded fallback. Subsequent checks used the preview process's journal and confirmed the repaired theme loaded without QML errors or fallback. A temporary probe verified a nonempty selected user and opened both pickers without errors; it was removed and never deployed. The socket warning in offline preview reflects the absence of a live SDDM daemon connection.
- User feedback confirms the lockscreen and final login-screen logo fix work. The 2026-10-14 alternate-theme visual review rendered the lock surface for Catppuccin, Everforest, and Nord; its durable findings are in [quickshell-theme-visual-validation.md](quickshell-theme-visual-validation.md). Automated checks verified greeter loading and picker initialization, not real credential submission to SDDM. Wrong-password visuals in a live greeter, power actions, keyboard/session selection across multiple users, multi-monitor/scaling, all-theme SDDM rendering, suspend/resume and lock-owner failure recovery remain unverified.

## Penpot result

File: **Redesign** (`8a4f1bc7-db1f-80ff-8008-c6f6cffb2a27`). The approved reusable credential control is in `01 · Foundations — R1`; approved screens are on `06 · Lockscreens — R1` (`354ba062-72fc-8008-8008-c8869d73f5c6`):

- `Session lock · ready` — a wallpaper-backed Wayland session lock with focused password input, Enter/Unlock affordance, and Shutdown/Restart/Suspend controls.
- `SDDM greeter · ready` — a separate pre-login design with user/password/sign-in in the card, **Desktop session selection outside the card at bottom-left**, and centered power controls.

| Screen | Board ID |
| --- | --- |
| Session lock · ready | `354ba062-72fc-8008-8008-c8869d8c5abe` |
| SDDM greeter · ready | `354ba062-72fc-8008-8008-c8869e68816d` |

## Approved layout — authoritative for implementation

Coordinates below are logical pixels relative to each 1920×1080 reference board. Use responsive anchors at runtime; do not copy the greeter board's absolute canvas offset. Live Penpot is the visual source of truth. [Gate B review history](quickshell-lockscreen-gate-b-review.md) records superseded revisions.

- **Cards:** 424px wide, 24px horizontal padding, 24px radius; both vertically centered. Lock: `(748,358)`, 424×364. Login: `(1120,344)`, 424×392. Lock heading/identity/action/hint share a centerline. Login title, labels and controls share the left edge at x=1144.
- **Credential:** 376×56, radius16, 24px lock icon, 16px horizontal padding and icon/text gap. Focus/error border is **2px inside-aligned**. A centered border was clipped by the component and produced thin straight edges/thick corners; preserve the fix. The 48px field-to-action gap reserves 32px for the error extension plus 16px separation. Actions remain 160×40. Enter submits; no password reveal affordance.
- **User selector:** 376×40, left-aligned label at 16px inset; separate canonical 24px downward chevron at 16px right inset, vertically centered. Do not append a chevron character to the label string.
- **Desktop session:** separate 240×40 footer control at `(48,976)`, caption at `(48,952)`. Same label/icon insets; upward chevron. Activate to open an upward picker from SDDM's available session model; selection updates the footer without submitting credentials. Restore the selected user's remembered session where supported. Arrow navigation, Enter selects, Escape closes and restores trigger focus. Keep session selection outside the sign-in card.
- **Brand:** approved Folded badge KMD monogram with trailing dot, top-left `(48,48)`, 48×48 on both screens. Linked `brand/kmdot` component `354ba062-72fc-8008-8008-c87ee54dd13e`; reference `Draft · kmDot Folded badge rev 4`. Scale the native 24px geometry and 1.8px stroke proportionally by 2 (3.6px displayed stroke). Use theme text for letters and primary for dot. Existing repo geometry: `config/quickshell/components/r1icons.js`, renderer `R1Icon.qml`. No KMDOT text replacement or alternate logo revision.
- **Power:** retain Shutdown/Restart/Suspend on both screens, centered at x=832/960/1088. Icons 24px at y=968, centered captions y=1000, 8px icon/caption gap, 64px bottom margin.
- **Clock:** lock has right-aligned clock/date at the top-right, 48px outer inset. Login has one large clock/date block on the left; no duplicate top-right clock. Technical theme/backend notes remain hidden design annotations, not UI copy.

Canonical credentials: default `354ba062-72fc-8008-8008-c885e6ae4648`, focus `354ba062-72fc-8008-8008-c885e6f5b40e`, error `354ba062-72fc-8008-8008-c885e74e39b9`. Chevron: `cfe1987a-fff1-803d-8008-c75956fd6bcf`. See [credential contract](quickshell-lockscreen-design-proposal.md).

**Acceptance scope:** the two ready-state screens, including the corrected border, external session selector and logo placement. Expanded user/session pickers and full error/authentication states were outside the approved Penpot ready-state scope; the runtime pickers and authentication are now wired. Responsive/multi-monitor behavior, long values and all-theme rendering still need broader validation. See the verification record above for the user-confirmed results.

## Repo pointers for follow-up work

- Lock UI/authentication: `config/quickshell/menu/LockScreenSurface.qml`, `config/quickshell/shell.qml`, `config/quickshell/scripts/lock-screen.sh`.
- Lock entry points: `config/hyprland/keybinds.lua`, `config/hyprland/hypridle.conf`, `config/quickshell/menu/SystemLauncher.qml`.
- Greeter source and deployment: `config/sddm/themes/kmd-quickshell/`, `config/sddm/sddm.conf`, `sync/sddm.sh`, `theme-switcher/hooks/sddm.sh`.
- Restart policy: `theme-switcher/main.sh` guards the normal Quickshell restart hook. Avoid killing the lock owner while locked.
- Edit repo sources, then deploy through the matching sync script. Preserve unrelated AttentionMode and top-bar work. This follow-up is included in the accompanying `feat(lockscreen): replace lock and login screens and fix authentication` commit; inspect git status before further edits.

The boards use the current TokyoNight wallpaper and R1 palette as a visual snapshot, with a `night.base` overlay at 68% opacity as a screen-specific contrast treatment. Runtime colors should come from the active theme’s semantic Quickshell roles; runtime wallpaper should come from that theme’s existing wallpaper selection path. The SDDM greeter and session lock share the design language and credential component, not an authentication process.

## Feasibility recorded before design approval

The version/API observations below are prior research, not rechecked during the documentation handoff. Verify installed versions and the relevant official APIs before coding.

The current machine reports Quickshell 0.3.1, Hyprland 0.56.2, and hyprlock 0.9.6. The running Wayland compositor advertises `ext_session_lock_manager_v1`. Quickshell 0.3.1 exposes `WlSessionLock` and PAM through `PamContext`, so an in-session lock can be implemented without a fullscreen-overlay shortcut. Quickshell requires a lock surface for each screen and reports when the session lock is secure. Its documentation warns that if the owning Quickshell process exits while locked, the compositor keeps the session secure but can leave it visually blank and unusable. This is the main reliability risk to solve before changing the default lock path. [WlSessionLock](https://quickshell.org/docs/v0.3.1/types/Quickshell.Wayland/WlSessionLock/) · [PamContext](https://quickshell.org/docs/v0.3.1/types/Quickshell.Services.Pam/PamContext/)

SDDM remains feasible as a separate Qt Quick greeter. It uses SDDM’s existing user/session models and login/power callbacks; it cannot use Quickshell’s session-lock or PAM objects. SDDM reads theme values from `theme.conf` and its adjacent `theme.conf.user` override, which makes active-theme synchronization possible in principle, but the installed theme lives in a root-owned system directory. A safe, narrow update path for those values needs a small implementation spike; do not add broad passwordless sudo or make executable theme code user-writable. [SDDM theming](https://github.com/sddm/sddm/wiki/Theming)

Hypridle already handles the logind lock signal and suspend path. Its documentation recommends `inhibit_sleep = 3` when a locker relies on the Wayland session-lock protocol, so suspend waits for the lock to be confirmed. [Hypridle](https://wiki.hypr.land/Hypr-Ecosystem/hypridle/)

## Original implementation sequence — historical

1. **Read the accepted screens and inspect the runtime.** Gate B is complete for LOCKSCREEN-01 rev 4. Start from the layout and source pointers above; verify installed APIs and choose a lock-owner/restart strategy. New reusable assets or design-system changes still follow the proposal workflow.
2. **Prototype the Quickshell locker in the repo.** Add a `WlSessionLock` surface for every active screen, acquire keyboard focus, and display the credential component’s visual contract with Quickshell’s `PamContext`. Use a dedicated PAM service file that includes the system’s normal authentication policy. Never log or persist entered passwords. Do not expose the input until all lock surfaces are confirmed secure.
3. **Make lifecycle behavior safe.** The current `theme-switcher/hooks/quickshell.sh` kills every process named `quickshell` and starts it again. A theme change while a session lock is held could therefore leave the compositor securely locked with no usable lock UI. Before rollout, test an ownership/restart strategy that defers shell restarts while locked, and verify how to recover from a locker process failure. A second Quickshell process alone is not sufficient while the hook uses `pkill -x quickshell`.
4. **Connect every lock entry point once.** Route Super+L, the System Launcher Lock action, and hypridle’s `lock_cmd` through one idempotent lock command. Preserve `before_sleep_cmd = loginctl lock-session` and set the hypridle sleep inhibitor after confirming the exact installed configuration syntax. Avoid starting two lockers for one lock request; the protocol permits one active lock.
5. **Follow active Quickshell theme data.** Resolve the current theme from the already-generated `Colors.qml` roles and the selected wallpaper path. Keep this runtime palette semantic (`surface`, `surface_high`, `primary`, `text`, `text_alt`, `error`) so every supported theme applies without per-theme QML branches.
6. **Prototype SDDM color synchronization.** Preserve SDDM’s user/session models, login behavior, and power callbacks. Keep its wallpaper synchronized through the existing wallpaper scripts. Test a narrowly scoped, validated way for the theme switcher to update SDDM’s theme values despite the system-owned theme directory; only then add the hook and sync behavior.
7. **Migrate in stages.** Keep hyprlock installed and restore its command through the repo if any lock reliability issue appears. Switch the default only after supervised validation. All config changes remain in the repo and deploy through the corresponding `sync/` scripts.

## Broader validation checklist

- Correct password unlocks; wrong password clears the field and displays the error state; repeated failures use the normal PAM protections.
- Every monitor is covered before the lock reports secure. Test monitor removal/addition while locked, mixed scaling, focus, keyboard layout, and cursor behavior.
- Idle lock, explicit lock, `loginctl lock-session`, suspend/resume, and DPMS wake all enter exactly one lock surface. Confirm sleep cannot race ahead of lock acquisition.
- Quickshell reload, theme switch, lock process exit, and failed startup do not strand the session without a recovery route. Keep a second administrative session available during early testing.
- SDDM accepts valid credentials, reports invalid ones, preserves user/session selection, and keeps power actions correct. Check all five themes and ensure a theme change updates the next greeter launch.
- Compare all five active palettes for text contrast and credential focus/error visibility; verify wallpaper crop and legibility on each connected display.

## Follow-up lifecycle and layout questions

- What lock-owner/restart strategy keeps the compositor secure and the UI recoverable across the current Quickshell theme hook’s restart behavior?
- Which least-privilege mechanism updates SDDM’s adjacent `theme.conf.user` safely when a user changes themes, or should SDDM use a wallpaper plus fixed neutral colors instead?
- How should the approved layout adapt to smaller displays and long user/session names while preserving keyboard access and the separate session control?

These questions concern broader validation and future hardening. The basic lockscreen and greeter repairs are complete. Hyprlock remains installed, but restoring its former UI would require restoring the removed repo configs and command routing before syncing.
