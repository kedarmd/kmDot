# Integrated kmDot launcher

Phase one replaces both the command hub and the separate Applications picker
with the local oma-cast implementation. Further launchers migrate one at a time,
with user verification required before starting the next one. Dropdowns are
outside this launcher pass.

## System presentation (verified by user)

System (Super+Esc) opts into `components/CastLauncherView.qml` through
`LauncherBase.castStyle`. Every other LauncherBase subclass retains its original
presentation. The opt-in renderer shares the existing controller, search,
selection and activation handlers. All five System actions, including Shutdown,
dispatch immediately without confirmation. The shared confirmation popup remains
for Wi-Fi/Bluetooth forget operations and Handy recording deletion. The new view reuses the imported
BrandMark, KeyHint, PointerMoveGate and UI font definition; the old renderer stays
available during the per-launcher review process.

The direction is the user's selected local oma-cast baseline: 680×520 card,
20px corners, 64px search header, 40px footer, 56px rows, 15px medium titles and
12px subtitles. System now uses the same existing surface/outline and selected
foreground/background roles as the migrated launcher. Theme files, role schemas
and Tokens.qml are unchanged. The `docs/quickshell-theme-audit.md` referenced by
AGENTS.md is absent in this checkout; these mappings follow the existing migrated
launcher rather than introducing palette values or new semantic roles.

Live read-back from the isolated System fixture on 2026-10-24 confirmed those
dimensions, Adwaita Sans and five visible 56px rows. Keyboard search, empty
results, arrows, Escape, direct dispatch of all five actions without a modal,
and legacy-view focus passed without running a power command. The optional check is:

```bash
node tests/quickshell-launcher/system-view.mjs
```

The fixture copies the repo configuration into a temporary directory, generates
a Nord palette, reads real QML geometry and uses an inert command handler. Its
result is implementation validation, not user acceptance of the new appearance.
System was visually inspected on the 2560×1440 external screen. Other screen
sizes/scales remain unverified. The user verified System and requested immediate
execution of all its actions. Subsequent components still require individual
user verification before moving on.

## Shared confirmation popup (verified by user)

The shared Wi-Fi/Bluetooth forget and Handy recording-delete popup follows the
same visual direction while keeping its compact confirmation layout: 424px
width, content-driven height, 20px corners, 1px outline, 17px medium heading,
14px body text, and 34px buttons with 8px corners. It reuses the migrated font and
KeyHint component. Existing theme roles provide the surface, foreground, outline,
warning glyph and destructive action colors; no theme palette changes were made.

PopupBase exposes opt-in chrome properties and PillButton exposes a font-family
property with its previous default. Only ConfirmPopup changes those defaults.
Handy's delete call now supplies semantic content and action colors rather than
fixed height, oversized typography and spacing overrides. Handy itself is not
restyled in this pass. System remains confirmation-free.

Default Cancel selection, arrow/Tab choice, Enter/Space activation, Escape,
backdrop dismissal, custom action labels and confirm/cancel signals remain.
Mouse confirmation uses the existing once-only keyboard activation guard.

```bash
node tests/quickshell-launcher/confirmation-view.mjs
```

This isolated, inert-caller fixture checks actual QML geometry, long plain-text
messages, both button labels, keyboard/mouse interactions and once-only signals.
On the 2560×1440 external screen its long Wi-Fi example measured 424×238 and its
Handy example 424×224, with both buttons and messages fitting. The rendered
examples were visually inspected; other screens/scales remain unverified. No
devices or recordings are changed by this fixture.

## Entry points

| Entry point | Initial filter |
| --- | --- |
| Super+Space / `scripts/launcher.sh` / `kmdot-launcher` socket | Applications |
| Super+K / bar kmDot button / `kmdot-kmdot` socket | All |

Both routes use the same launcher object, backend and overlay surface. Switching
routes while open changes the filter and clears the query. Repeating the current
route closes it. The top-right selector still offers All, Applications and
Commands. The Applications result selects that filter in place. Themes,
wallpapers, clipboard, connections, Handy, shortcuts and system menus are
discoverable in All and retain their existing implementations.

The imported presentation uses the reference's centered 680×520 card, 20px
corners, 64px header, 40px footer, Adwaita Sans text, Nerd Font icons, 56px result
rows, action panel and themed scrim. The reference's zoom and compact settings
remain supported, as do favorites, aliases, calculator/history, root filters,
quicklinks and explicit terminal agent handoffs.

## Deployment and data

Edit this repo, then run `./sync/quickshell.sh` and `./sync/hyprland.sh`.
Source changes require a full Quickshell restart; theme/config FileViews continue
to watch their data. For an unlocked desktop:

```bash
qs kill -p "$HOME/.config/quickshell/shell.qml"
quickshell -d -n -p "$HOME/.config/quickshell/shell.qml"
```

The Quickshell sync disables the old `kay-cast.service` only if it carries its
original managed-service marker. It imports each legacy `kay-cast` XDG directory
to `kmdot-launcher` once, using a staged copy, and excludes `runtime` checkout
links. Existing kmDot launcher data is never overwritten. The original checkout,
legacy data, disabled service file and dormant CLI link remain available for
reference or rollback; none is required by the running kmDot launcher.

Preferences/custom commands live in `$XDG_CONFIG_HOME/kmdot-launcher`, database
documents in `$XDG_DATA_HOME/kmdot-launcher/db`, and cache/state in the matching
XDG roots (with the standard home-directory fallbacks). These are outside the
synced config tree so re-syncs do not erase them. The removed picker's old
`kmdot/app-usage.json` is left untouched; the integrated launcher uses the
imported oma-cast frecency database instead.

Environment overrides are now `KMDOT_LAUNCHER_AGENT`,
`KMDOT_LAUNCHER_TERMINAL`, `KMDOT_LAUNCHER_FONT_FAMILY` and
`KMDOT_LAUNCHER_THEME_FILE`. Set them in the compositor environment via the repo's
`config/hyprland/env.lua`, then sync Hyprland. The deprecated service's private
EnvironmentFile is no longer loaded by the main shell.

Apps and desktop commands start in independent user services so restarting the
shell cannot kill them. Desktop entry argv expansion and working directories
remain intact. No Python runtime or installer is included.

## Validation

```bash
node --test tests/quickshell-launcher/*.test.js
node tests/quickshell-launcher/smoke.mjs
bash -n sync/quickshell.sh config/quickshell/scripts/launcher.sh config/quickshell/launcher/bin/*
```

The regression suite covers ranking, filters, calculator behavior, aliases,
versioned stores, literal argv, agent lifecycle, all four theme renders, initial
data import, repeat syncs and fresh installs. The optional live smoke script
checks backend readiness, stores, app indexing, calculator, overlay show/hide,
both filter socket entry points and handoff to/from the existing Themes menu.
It restores the launcher's initial open/closed mode and does not launch apps,
paste text, switch themes or invoke power actions.

Migration validation on 2026-10-24: 110 regression tests passed; one installed
Omarchy fixture was skipped. Live smoke checks passed after a full restart and
after reapplying the active Everforest theme through its restart hook. One main
Quickshell process remained, the standalone service was disabled/inactive, and
notification/lock IPC still responded. Hyprland reported no config errors.
All/Applications renders were inspected on the 2560×1440 external display;
the laptop display and other scaling factors still need visual acceptance.

Source provenance and future upstream-import boundaries are recorded in
[`UPSTREAM.md`](../config/quickshell/launcher/UPSTREAM.md).
