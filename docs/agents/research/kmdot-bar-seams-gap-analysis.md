# kmdot bar seams + gap analysis (Omarchy "Quattro" compat)

Research for wayfinder ticket "kmdot bar seams and gap analysis" (map: Omarchy plugin support).
All refs are into this repo. Verified 2026-09-28: zero `Loader` in `config/quickshell`,
`BarModule.openPopup()` routes via `toggle.sh`, `Tokens.qml` uses snake_case `on_*`.

## 1. Bar construction

**Bar shell** — `config/quickshell/shell.qml`:
- One `Scope` (`shellRoot`, :9) owns all overlay instances as properties (:14–37) plus a `Variants { model: Quickshell.screens }` → per-screen `PanelWindow` (:149–152).
- Bar `PanelWindow`: anchors top+left+right (:156–160), `color: Colors.surface`, `implicitHeight: 42`, `exclusionMode: Auto` (:162–164).
- Three groups, all plain `Row spacing: 8` (:197–275): left = `Workspaces`; center = `AttentionMode` + `Kmdot` + `Clock { popupRef: calendarPopup }` + `Dnd`; right = `HiddenModules` tray + `Network` + `Bluetooth` + `Audio` + `Battery` + `Display`.
- Single shared `Tooltip` instance passed down; `IpcHandler target: "notifications"` (:170–195) is the only IPC surface — no generic plugin IPC.

**HiddenModules tray** — `config/quickshell/modules/HiddenModules.qml`: `Item, clip: true`, `default property alias modules` for inline children, hover chevron, 180ms open / 150ms-grace close, reusable `stayOpen` popup lock bound in shell.qml, click-through `MouseArea(NoButton)`, row `enabled: root.open`.

**BarModule contract** — `config/quickshell/components/BarModule.qml`: subclass supplies `glyph`/`text` (at least one), `active`, `fill`, snake_case `on_color`, `busy`, `dimmed`, `tooltipText`; open-path props `tooltip`, `sock`, `clickable`, **required `popupRef`** (anything with `anchorItem`); `signal wheeled`; `openPopup()` sets `popupRef.anchorItem = root` then execs `toggle.sh <sock>` (Left-only, no right-click verbs). Renders `ModulePill` + centered Nerd Font text; `busy` → spinner.

**Adding a module today** (static, no registry/loader): write `modules/<Name>.qml` extending `BarModule` (or bespoke `Item`+`ModulePill`), declare in shell.qml's rows with `tooltip:`+`popupRef:`, give its surface a unique `sockName`, re-run `./sync/quickshell.sh`, restart quickshell.

## 2. Theming pipeline

- Per-theme `themes/<theme>/quickshell.conf` (flat M3 `key=value`, canonical swatches per AGENTS.md).
- `theme-switcher/hooks/quickshell.sh:16-29` regenerates `~/.config/kmdot/quickshell/Colors.qml` (`pragma Singleton`, one `readonly property color` per line). `Tokens.qml` is never regenerated — derives tokens from `Colors`.
- **`on*` footgun**: `on`+UPPERCASE names parse as signal handlers → property silently missing → black fallback. All `on_*` snake_case + LIGHT; same reason for `BarModule.on_color`.
- **Restart-on-switch** (hook :31–44): `pkill` + `setsid nohup quickshell` relaunch because live-reload orphans socket servers. `toggle.sh` self-heal is only a backstop.

## 3. Popup/overlay coordination

- `shellRoot.closeAllExcept(except)` (`shell.qml:50-73`): closes launchers (`closeLauncher()`), popups (`close()`), `radioSurfaces`; toast excluded; Handy playback has 150ms deferred both-closed stop.
- **PopupBase** (`menu/PopupBase.qml`): fullscreen transparent `PanelWindow` (`visible: opened`), Overlay layer, Exclusive keyboard focus, Ignore exclusion. `open()` routes via `scope.closeAllExcept` + `applyAnchor()` + focus timer + `refreshItems()`; `close()`/`toggle()`; overridable `refreshItems()`/`openedChange()`; per-surface `SocketServer` (`Socket { onConnectedChanged: toggle }`); backdrop-click + Esc close.
- **LauncherBase** (`components/LauncherBase.qml`): dim+card in ONE `PanelWindow` surface; `openLauncher()`/`closeLauncher()` via `scope.activeLauncher`; subclasses must NOT re-declare `onOpenedChanged`; seams: `closeOnActivate`, `loading`, `footerAction*`+Tab, `promptMode`, `searchEnabled:false` nav surface + `bareKeyActions` vs chords-only `itemActions`, row seams (`itemTitle`, `itemStatusGlyph`, `itemSubtitleLive`, `itemProgress`, `itemBody`).
- **Positioning** (`components/popuppos.js` + `anchorItem` seam): module sets `popupRef.anchorItem` in-process before exec; `applyAnchor()` maps to global X, picks screen, clamps card `x` to `[10, w-10]`; `anchorGX` persists for sub-popup inheritance; no anchor → cursorpos screen + right-flush card.
- **Sockets + self-heal** (`scripts/toggle.sh`): node `net.connect` probe; missing/stale socket → `notify-send`, `pkill -x quickshell || true`, `rm -f $SOCK`, `setsid` relaunch, ≤15s poll. Sock inventory covers all launchers, dropdowns, and popups (see report).

## 4. Loader / error patterns

- **Zero `Loader` usage (verified by grep)** — everything statically instantiated in shell.qml. A broken QML file fails the whole process; no per-component isolation or fallback exists. Nearest: `Image.onStatusChanged` art fallback, `nmcli` parse defensiveness, clipboard atomic-`mv`+`flock`. QML errors go to stderr/journal (discarded by hook/toggle.sh `>/dev/null`+`nohup`); no in-repo log viewer.

## 5. Config/sync model

- Repo `config/<app>/` is source of truth; `sync/<app>.sh` = `rm -rf` + `cp -r` + `ln -sf` (destructive). `sync/quickshell.sh` also `chmod +x scripts/*.sh` and restarts clipboard daemon. Registration via `config-install.sh` `APPS` array.
- No plugin seam exists. Natural fit: `config/quickshell/plugins/` (or `omarchy/`) carried by the existing whole-tree `cp -r`; deployed path is `~/.config/kmdot/quickshell/...` via the `~/.config/quickshell` symlink. Theme assets would follow `themes/<theme>/` + hook pattern.

## 6. Gap analysis (Omarchy capability → kmdot)

| Omarchy capability | kmdot verdict |
|---|---|
| Inject `bar` / `moduleName` / `settings` props | MISSING — static QML, hand-wired props. Shim must synthesize. |
| `bar.foreground/background/urgent/fontFamily/position/run/tooltip/requestPopout` | PARTIAL — `Colors`/`Tokens` cover colors; font hardcoded; position fixed top; `run` ≈ `Process.exec(sh -c)`; tooltip = shared `Tooltip`; `requestPopout` ≈ `openPopup()`+socket+`closeAllExcept`. No unified `bar.*` object — shim maps each. |
| `summon/hide/toggle` IPC per plugin id | PRESENT (different mechanism) — per-surface socket + `toggle.sh`. Shim needs id→sock registry. |
| `shell.json` layout + inline settings | MISSING — layout hardcoded in QML. Shim parses `shell.json` itself, projects onto loader row. |
| Hot reload on save | MISSING/HOSTILE — live-reload breaks sockets; kmdot restarts. Prefer restart or scoped `Loader` re-`source`. |

**Top shim risks**: (1) no `Panel`/`KeyboardPanel` bases — re-home onto `PopupBase`/`LauncherBase` or raw `PanelWindow`+`popuppos.js`; (2) no `Style` singleton — map `Style.*`→`Colors`/`Tokens`, survive regen via restart; (3) no `WidgetButton` — re-wire to `BarModule`/`openPopup()`+`toggle.sh`, Left-only; (4) `on*` footgun — rename to snake_case at boundary; (5) glyph literal-vs-escape footgun — 5-hex PUA must stay literal chars, Nerd Font Propo only; (6) no `Loader` isolation — shim introduces per-plugin `Loader` + fallback, a new pattern for this tree.
