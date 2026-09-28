# PROTOTYPE: themed pilot plugin proof (throwaway)

Wayfinder map "Omarchy plugin support in kmdot quickshell bar", ticket
"Themed pilot plugin proof in kmdot bar". **Throwaway by design** — proves
the spec's hard seams, then the rollout spec replaces it. Do not build on
top of this; do not merge to main.

## Question answered

Can one Omarchy plugin (omarchy.clock, the research-recommended pilot)
run inside the kmdot bar through a thin shim — themed, anchored,
coordinated, and isolated?

## What the prototype contains

- `plugins/omarchy.clock/` — **byte-identical** vendored copy of Omarchy
  Quattro `shell/plugins/panels/clock/` at commit `b18ab49`
  (manifest.json, Model.js, BarWidget.qml, Panel.qml). No hand-porting.
- `Ui/`, `Commons/` — Omarchy shell components vendored **verbatim**
  (BarWidget, Panel, PanelController, WidgetButton, KeyboardPanel,
  PanelKeyCatcher, OpticalGlyph, PanelToolTip, PanelActionButton,
  TextField, BorderSurface, BorderOverlay, PluginBarApi, Border,
  BorderGeometry.js, Util, IpcRegistry, ShellIpc), EXCEPT:
  - `Commons/Style.qml`, `Commons/Color.qml` — kmdot-written Tier-1
    shims fed from `Colors` (full kmdot theme follows all 5 themes via
    the normal Colors.qml regen + restart). State colors/border widths
    are legible approximations, not canonical mappings.
- `compat/PluginHost.qml` — mounts the vendored BarWidget in a per-plugin
  `Loader` (isolation + fallback glyph row on `Loader.Error`), injects
  `bar`/`moduleName`/`settings` iff present, feeds the `PluginBarApi`
  facade from `Colors`, owns the `kmdot-plugin-<id>` socket, and joins
  `closeAllExcept` in both directions (requestPopout closes kmdot
  surfaces; the host's `close()` lets kmdot close the plugin panel).
- `compat/PluginShellApi.qml` — Tier-1 `updateEntryInline` (in-memory
  live-patch + log, no shell.json write) and summon/hide/toggle routing;
  Tier-2 `firstPartyServiceFor` stubbed to null + stderr.
- `plugins.json` — curated-allowlist shape (`{id, src, rev, enabled}`).
- `shell.qml` — host mounted in `centerGroup` after the native Clock,
  marked PROTOTYPE; added to the `closeAllExcept` popup list.

## Known prototype gaps (for the rollout spec, not this branch)

- While the clock panel is open, clicks on kmdot bar modules are consumed
  by KeyboardPanel's fullscreen dismiss layer (only registered click
  targets are forwarded). Rollout needs click-through or registration.
- `switchPanelFrom` returns false (single pilot plugin, no Tab target).
- `run()` shells out; the `omarchy-menu-timezone` middle-click dep is
  missing on CachyOS and logs a warning (Tier-2 degradation proof).
- Right-click format cycling works through the plugin's own button
  (kmdot's Left-only rule applies to BarModule, not vendored buttons).
- No `plugins-update.sh` yet; update = re-vendor + diff review by hand.
- Perf budget: measure open latency / memory during verification.

## Verify

1. `./sync/quickshell.sh`
2. `pkill -x quickshell || true; setsid nohup quickshell >/tmp/opencode/prototype-clock.log 2>&1 &`
3. `journalctl --user -u quickshell` or the log: no QML errors for
   `qs.Ui`/`qs.Commons`/clock; socket
   `$XDG_RUNTIME_DIR/kmdot-plugin-omarchy-clock.sock` exists.
4. Left-click the pilot clock: calendar panel anchors under it; Esc and
   outside click close; opening a kmdot popup closes it and vice versa.
5. `theme-switcher/main.sh everforest` (or any theme): pilot follows.
6. Break it (temporarily typo the vendored entry): fallback glyph row,
   bar stays up.

## Attribution

Omarchy (Basecamp, MIT): https://github.com/basecamp/omarchy
