# Omarchy plugin runtime contract (Quattro branch, commit `b18ab49`)

Research for wayfinder ticket "Omarchy plugin runtime contract" (map: Omarchy plugin support).
Refs inspected read-only under `/tmp/opencode/omarchy-ref/omarchy` (not committed).
All repo-relative paths below are into the Omarchy repo. Verified 2026-09-28:
`injectProps` `in`-check (`Bar.qml:2002-2005`), `PluginBarApi.qml` exists,
`summon` payload-drop comment (`shell.qml:1158`), numeric `schemaVersion === 1` (`PluginRegistry.qml:48`).

## Big picture

Single long-lived Quickshell process (`shell/shell.qml` = `ShellRoot`); bar, panels,
overlays, menus, services are all in-process plugins. The kmdot target pattern is
**one `bar-widget` whose entry QML is a bar button that internally `Loader`s a
`Panel.qml`** — the details panel is nested inside the widget, NOT a separate
`panel` kind (built-in clock is the reference). Base classes: `shell/Ui/BarWidget.qml`,
`shell/Ui/Panel.qml`.

## manifest.json schema (`PluginRegistry.qml:43-90`, CLI mirror `bin/omarchy-plugin-validate`)

- Required: `id`, `name`, `version`, `kinds` (non-empty), `entryPoints`; `schemaVersion`
  must be numeric `1` exactly. Optional: `author`, `description`, `license`.
- Kinds and entry-point keys: `bar-widget`→`barWidget`, `bar`→`bar`, `panel`→`panel`,
  `overlay`→`overlay`, `menu`→`menu`, `service`→`service`. Manifests may declare several
  kinds (menu+bar-widget, service+bar-widget). Runtime only warn-and-skips on mismatch.
- Entry values: safe relative paths (no leading `/`, no `..`), must exist on disk (CLI check).
- `barWidget` block (optional): `displayName`, `description`, `category`, `allowMultiple`
  (default false), `defaultSection` (left/center/right; runtime default `center`),
  `defaults` (inline default settings), `schema` (setting descriptors), `settingsForm`, `aliases`.
- `keepLoaded` (bool, default false): panels/overlays/menus stay `active` between summons;
  services survive hot-reload unload.
- `activation`: vestigial — only `agents` declares `"on-demand"`, nothing reads it. Ignore.
- `omarchy` block: `capabilities` (only real value `["authentication"]` on polkit),
  `clonedFrom` (clone routing/restore-built-in).
- Validation: id regex `^[A-Za-z0-9][A-Za-z0-9._-]*$`, `omarchy.*` reserved for first-party,
  **no symlinks** anywhere in the folder, `qmllint -I $OMARCHY_PATH/shell` for QML.

## Host injection + `bar` API (`Bar.qml:1999-2006`, `Ui/PluginBarApi.qml`)

- Bar-widget entries declaring `bar`/`moduleName`/`settings` get them filled **iff the
  property exists** (`in` check). First-party gets the real Bar root; third-party gets a
  `PluginBarApi` facade. `settings` = inline layout-entry object, live-patched without rebuild.
  (`omarchyPath`/`shell`/`manifest`/registries go only to panel/overlay/menu/service/bar entries,
  third-party ones capability-scoped facades — explicitly not a sandbox.)
- `bar` surface: `foreground`, `background`, `urgent`, `barForeground`, `fontFamily`,
  `position`, `vertical`, `barSize` (all live-bound); ops `run(cmd)`, `showTooltip/hideTooltip`,
  `requestPopout/releasePopout` (**one-popup coordinator**), `switchPanelFrom` (Tab cycling);
  facade extras: click-target registration, `moduleWidgets(id)`, `setCenterHoverRevealSuppressed`.
- `bar.shell` is the deep surface: full `ShellRoot` for first-party, scoped `PluginShellApi`
  for third-party. Widgets touch `bar.shell.updateEntryInline`, `summon/hide/toggle/isPluginOpen`,
  `firstPartyServiceFor(...)` — the shim must implement at least these or accept degraded widgets.

## Shared imports (`qs.Commons`, `qs.Ui`)

`BarWidget` (button base + `setting(name, fallback)` + `broadcast()`),
`Panel` (popup base: `opened`, `open/close/toggle/closeForPopoutSwitch/switchPanel`, auto-IPC via
`ipcTarget`+`manageIpc`), `PanelController` (state), `KeyboardPanel` (layer-shell popup;
**required** `anchorItem`+`bar`; outside-click dismissal), `PanelKeyCatcher` (key dispatcher),
`WidgetButton` (pill button + tooltip + click-target registration),
`Style` (structural tokens), `Color` (palette, TOML-fed via `applyTheme` IPC), `Util`, `ShellIpc`.
Widget QML otherwise uses only stock Quickshell modules (Pipewire/Mpris/UPower/Networking/Io/Hyprland)
plus JS `Model.js` sidecars — no Omarchy C++ plugins.

## Panel lifecycle (two paths — do not conflate)

- Standalone panel/overlay/menu: Loaders in `shell.qml:1349-1393`; must expose
  `open(payloadJson)`/`close()`; `summon` sets flag + queues payloads, `hide` closes,
  `toggle` flips, `call` reaches only already-loaded instances (bar-widget popups NOT via `call`).
- **Bar-widget popups** (the kmdot target): mounted in-bar, one instance per monitor;
  `summon/hide/toggle` route to `bar.summonBarWidget/...` → live instance's `open()`/`close()`
  **with NO payload** (dropped, `shell.qml:1158`). Instance must expose `open`/`close` fn + `opened` prop.
- Canonical nested shape: entry forwards `open/close/toggle/closeForPopoutSwitch`, mirrors
  `opened`/`popoutSwitchClosing` from inner `Loader(Panel.qml)`; `injectPanel()` pushes
  `bar`+`anchorItem`(button)+`hostWidget`(self) on load/bar-change; inner panel sets
  `manageIpc: false`, `open()→controller.show()`, `close()→controller.hide()`,
  `switchPanel(d)→bar.switchPanelFrom(hostWidget||root, d)`, `KeyboardPanel{anchorItem; owner; bar; open}`
  + `PanelKeyCatcher{close→root.close(); tab→switchPanel}`.
- IPC: `omarchy-shell shell summon|hide|toggle|call <id>` over a private `XDG_RUNTIME_DIR` socket
  (+ `qs ipc` fallback). Targets named per plugin (`omarchy.clock`, `background`, `media`, …);
  **no `bar` target**. Single-`IpcHandler`-per-target rule — shim must not double-register
  across instances (`manageIpc: false` + own handler is the established pattern).

## shell.json (wholesale replace, no deep-merge; `version: 1` required)

`bar.{id,position,transparent,centerAnchor,layout:{left,center,right}}`,
`plugins[]` (non-bar kinds), `disabledPlugins[]` (first-party off-switch; first-party widgets
stay loadable off-bar). Every entry = one instance, **settings inline on the entry**.
Third-party enabled ⇔ present. `allowMultiple` permits repeats (all shipped manifests `false`).
Custom inline modules: `{type: command|qml, exec, interval, tooltip/text, onClick/…, source}`.

## Hot-reload

`inotifywait` on `~/.config/omarchy/plugins` (dot-paths/`.git` excluded) → 150ms debounce →
`reloadPlugins()`: unload panels/widgets/services (**except `keepLoaded`**), `Qt.clearComponentCache()`,
`rescan()`, re-sync. Manual `rescanPlugins`; `reloadConfig` re-reads shell.json only.
Clone workflow preserves `omarchy.clonedFrom` so removal restores the built-in.

## Hostile-to-re-hosting findings (shim consequences)

1. `qs.Ui`/`qs.Commons` imports are load-bearing → reuse Omarchy's dirs on the import path as
   `qs.*` or re-implement ~6 components (reuse drags theme singletons along).
2. `Color`/`Style`/`Border` singletons are global + TOML-driven → feed real theme TOML or stub;
   widgets + `KeyboardPanel` read them pervasively.
3. `bar` facade emulatable as `QtObject`; `bar.shell.*` is the deep surface (min: `updateEntryInline`,
   `summon/hide/toggle/isPluginOpen`, `firstPartyServiceFor`→null-ok).
4. Per-monitor instance model (`moduleWidgets`/`broadcast`/`findPanelWidget` via focused monitor) →
   single-bar host must define what `summon` opens.
5. Hyprland assumptions throughout (focus routing, layer-shell namespace, exclusive focus) — fine on
   kmdot/Hyprland, inherits behavior.
6. Widget service imports are stock quickshell — risk is behavioral, not missing modules.
7. Popout exclusivity (`requestPopout`/`closeForPopoutSwitch`/`popoutSwitchClosing`) must be replicated
   when hosting >1 Omarchy widget or popups overlap.
8. Single-IpcHandler-per-target — no double registration across instances.
9. Widgets shell out to `omarchy-*` CLI helpers — must exist on PATH or actions fail.
10. No sandboxing; trust is install-time (validate + review-before-enable).
