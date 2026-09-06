# Research: Quickshell sharing patterns for deep modules

Ticket: Research Quickshell sharing patterns for deep modules (sub-issue of the
wayfinder map "deepen the quickshell modules"). Question: how should deep shared
modules be built — QML inheritance vs singleton vs helper module vs .js library —
so the six grillings can place their seams idiomatically?

Grounding: repo files under `config/quickshell/` (quickshell 0.3.0, Arch) plus
the Quickshell guide/type docs and the Qt QML docs (primary sources, cited per
claim). No secondary write-ups.

## TL;DR decision table

| Need | Pattern | Why |
|---|---|---|
| Shared **visual chrome** (launcher card, popup overlay) | QML file-type **inheritance** (base `.qml`, subclasses override seams) | Already proven twice in-repo (`LauncherBase`, `ConnectionDropdownBase`); Qt/Quickshell treat every uppercase `.qml` as an implicit type whose root props/functions/signals are its interface |
| Global **stateless** lookups (colors, tokens, geometry) | **`pragma Singleton` + `Singleton` root** for QML values; **`.js` library** for pure functions | Repo precedent (`Colors`, `Tokens`, `DnDState`, `popuppos.js`); Quickshell requires the `Singleton` root type |
| Per-radio **stateful** backend (wifi, bluetooth, handy) | **Singleton store** (`QtObject`/`Singleton` root) + thin Dropdown/Launcher/Add **views** | One poller/poller-state, many views; avoids today's N-copies-of-state drift |
| Central **close-all-except** coordination | A **function on the shell `Scope`** (`shell.qml`), called from the two base types | The Scope already owns every instance; a singleton would invert ownership and risk init cycles |
| Unit-testable logic | Extract to **`.js`** (the only seam runnable outside `qs`) | QML surfaces can't execute outside the quickshell engine; `popuppos.js`-style pure functions run under plain `node` today |
| QML surface verification | **Reload + socket-toggle + log check** (documented per spec) | No in-repo harness exists and none is installable without one; see §6 |

## 1. QML inheritance is the idiom for shared visual chrome

**Sources.** Qt: "to create an object type, a QML document should be placed into
a text file named `<TypeName>.qml`… automatically recognized by the engine as a
definition of a QML type… The root object definition defines the attributes that
are available" (`doc.qt.io/qt-6/qtqml-documents-definetypes.html`). Quickshell
guide ("QML Language → Creating types"): "Every QML file with an uppercase name
is implicitly a type… All properties defined for the root object are visible to
the consumer" (`quickshell.org/docs/v0.1.0/guide/qml-language`).

**In-repo proof it works.** `components/LauncherBase.qml` (an `Item` root with
`scope`, `sockName`, `items`/`pool`/`results`, `filterAndSort()` /
`matchScore()` / `refreshItems()` / `onOpenedChange()` / `activate()` seams)
has **10 subclasses** (`AppLauncher`, `KmdotLauncher`, `SystemLauncher`,
`ThemeLauncher`, `ConnectionsLauncher`, `WifiLauncher`, `BluetoothLauncher`,
`KeybindsLauncher`, `ClipboardLauncher`, `HandyLauncher`). `menu/ConnectionDropdownBase.qml` (a
`PanelWindow` root with `opened`/`scope`/`anchorItem`/`anchorGX`/`sockName`/
`socketEnabled`/`escapeCloses`/`cardWidth`, `open()`/`close()`/`toggle()`/
`refreshItems()`/`openedChange()`, `default property alias content`) has **5
subclasses**: `WifiDropdown`, `BluetoothDropdown`, `WifiAddPopup`,
`BluetoothAddPopup`, `ConfirmPopup`.

**Recommendation.** Keep inheritance for anything that renders: future shared
chrome (a unified `PopupShell`, a coordinator-aware base) should be a base
`.qml` file with `PanelWindow`/`Item` root, configuration properties, and
no-op seam functions (`refreshItems()`, `onOpenedChange()`-style). Subclasses
set properties and override seam functions; they must NOT re-declare the base's
`onXChanged` handlers (both base files document that shadowing breaks the
focus-timer handler — Qt signal-handler override semantics).

## 2. Popup chrome: the other 8 CAN inherit `ConnectionDropdownBase`

**Inventory (13 popup surfaces + 1 toast).** Inheriting today (5): `WifiDropdown`,
`BluetoothDropdown`, `WifiAddPopup`, `BluetoothAddPopup`, `ConfirmPopup`.
Standalone `PanelWindow` duplicates (8): `BatteryPopup`, `VolumePopup`,
`CalendarPopup`, `ServerModeDropdown`, `HandyPopup`, `OpenCodeUsagePopup`,
`DisplayPopup`, `NotificationCenter`. (`NotificationPopup` is the 14th surface
but a different beast — `keyboardFocus: None`, no card, auto-dismiss toast —
and should NOT inherit.)

**What the 8 duplicate.** Compared line-by-line against
`menu/ConnectionDropdownBase.qml` (162 lines), each standalone popup
re-implements: the transparent fullscreen `PanelWindow` + `BackgroundEffect`
blur-subtract + `Overlay`/`Exclusive` layer-shell block, `anchorItem`/`anchorGX`
+ `applyAnchor()` + `pickScreen()` (`hyprctl cursorpos` via `Process`), the
`SocketServer` toggle, the 60 ms `focusTimer`, `open()`/`close()`/`toggle()`,
and the card `Rectangle` (`body.implicitHeight + 32`, `Pos.cardXFor` x-position,
backdrop click-to-close). The only file that imports the geometry differently
is none — all 8 `import "../components/popuppos.js" as Pos` exactly like the
base.

**What actually blocks them (small, enumerable).** Three deltas, each fixable
with one new seam on the base:

1. **Card-height cap.** Base hard-codes `height: body.implicitHeight + 32`.
   `DisplayPopup` needs `Math.min(body.implicitHeight + 32, 600)`;   
   `NotificationCenter` needs `Math.min(cardBody.implicitHeight + 24,
   root.height - 80)` (and names its column `cardBody`, not `body`). Seam:
   e.g. `property real maxCardHeight: -1` (`-1` = uncapped) honored by the
   base's card height binding. The `cardBody` naming is trivially renamed to
   `body` since the base exposes `default property alias content: body.data`.
2. **Escape behavior.** Base already has it: `escapeCloses` (default `false`) +
   `Keys.onEscapePressed`. `ConfirmPopup` sets `escapeCloses: true`;
   `socketEnabled: false` covers socketless use. Standalone popups that want
   Escape-to-close get it for free; no blocker.
3. **Custom open()/close() side effects.** `HandyPopup.close()` also stops
   playback; `CalendarPopup.open()` does sync-then-parse; `BatteryPopup.open()`
   has a narrower close-list (see §3). These are overrides of `openedChange()`/
   `refreshItems()`-style seams, not inheritance blockers — the base explicitly
   provides `openedChange()` for visibility-tied work.

**Recommendation.** Yes — migrate the 8 onto `ConnectionDropdownBase` (or its
successor `PopupShell` if a grilling renames it), adding the `maxCardHeight`
seam first. `NotificationPopup` stays standalone. Nothing in the Quickshell or
Qt docs argues against multi-level QML inheritance; the repo's own 10-deep
`LauncherBase` family is the precedent that it composes.

## 3. Coordination belongs on the shell `Scope`, not in each surface

**Sources.** Quickshell `Scope`: "Scope that propagates reloads to child items
in order"; "Convenience type equivalent to setting `Reloadable.reloadableId`
for all children" (`quickshell.org/docs/v0.2.0/types/Quickshell/Scope`). Qt
"Property access scopes": an id-declared object (`shellRoot`) is addressable
from bindings throughout its file, and the repo already passes `scope:
shellRoot` into every launcher/popup because "Scope does NOT parent its
children, so root.parent is null" (`components/LauncherBase.qml:48-51`).

**In-repo evidence of the problem.** Every surface hand-rolls its close-list
inside `open()`/`openLauncher()`, and the lists have **already drifted**:

- `ConnectionDropdownBase.open()` closes 11 named surfaces (incl.
  `wifiDropdown`, `bluetoothDropdown`, both Add popups, `confirmPopup`).
- `BatteryPopup.open()` closes only launcher/volume/calendar/server/display —
  it never closes `openCodeUsagePopup`, `handyPopup`, or any
  wifi/bluetooth dropdown.
- `ServerModeDropdown.open()` never closes `openCodeUsagePopup`/`handyPopup`.
- `LauncherBase.openLauncher()` closes 7 surfaces but no wifi/bluetooth
  dropdowns or Add popups.
- `shell.qml` itself holds the only complete registry: 25 named instances plus
  `activeLauncher`, and already cross-closes in two places
  (`batteryPopup`↔launchers, `activeLauncher` coordinator).

So "opening X closes Y" is O(N²) handwritten edges with demonstrable gaps —
the coordinator ticket's core exhibit.

**Recommendation.** Add one function on the shell Scope, e.g.
`function closeAllExcept(except)` iterating the owned instances, and call it
from exactly two places: `LauncherBase.openLauncher()` and the popup base's
`open()`. Do NOT make the coordinator a singleton: per the Quickshell guide,
singletons should be `Singleton`-rooted (non-visual), while the coordinator
must reference window instances owned by `shell.qml` — a singleton would invert
ownership and invite init-order cycles (§4 pitfalls). The `scope` property seam
already threads every surface to the Scope, so no signature changes are needed
beyond the base types.

## 4. Per-radio state goes in a singleton store; views stay thin

**Sources.** Quickshell guide ("Creating types → Singletons"): "put `pragma
Singleton` at the top… make the `Singleton` the root item of your type";
"Once a type is a Singleton, its members can be accessed by name from
neighboring files" (`quickshell.org/docs/v0.1.0/guide/qml-language`).
Quickshell `Singleton` type: "The root component for reloadable singletons.
All singletons should inherit from this type."
(`quickshell.org/docs/v0.2.0/types/Quickshell/Singleton/`). Qt: plain-QML
singletons otherwise need a `qmldir` entry; Quickshell synthesizes module
wiring (no `qmldir` exists anywhere in `config/quickshell/`, yet `import qs`
resolves `Colors`/`Tokens`/`DnDState` in 47 files).

**In-repo precedent.** Three singletons, all `pragma Singleton` + `Singleton`
root: `Colors.qml` (regenerated theme values), `Tokens.qml` (derived M3 tokens
+ `mix()`/`alpha()` helpers), `DnDState.qml` (persisted boolean via `FileView`
+ `JsonAdapter` — the template for stateful singletons: controlled mutation,
timers for file round-trips). Consumed by bare name after `import qs`
(every menu, module, and component file).

**The problem it solves.** Today each radio's state is duplicated per view:
wifi state lives in both `WifiLauncher` (scan/process/password flow) and
`WifiDropdown` (networks/saved/traffic); bluetooth in `BluetoothLauncher` +
`BluetoothDropdown`; handy in `HandyLauncher` + `HandyPopup` (each with its own
playback/retry/delete wiring). Two pollers, two truths.

**Recommendation.** One `Singleton`-rooted store per radio
(e.g. `WifiState`, `BluetoothState`, `HandyState`: non-visual, properties +
controlled functions, `FileView` persistence where DnDState-style durability
is wanted), with the Dropdown/Launcher/Add surfaces as thin views binding to
it. Heed the documented pitfalls: keep properties `readonly` where views must
not write, mutate only through store functions, and keep stores dependency-free
(no store→store imports — the guide warns circular singleton dependencies
deadlock initialization).

## 5. `.js` libraries are for pure stateless computation only

**Sources.** Qt ("Importing JavaScript Resources in QML"):
`import "<file>" as Qualifier` makes the file's functions available as
`Qualifier.fn()`; a script's imports/semantics are per-importing-document, and
`.pragma library` / `.import` variants control sharing
(`doc.qt.io/qt-6/qtqml-javascript-imports.html`).

**In-repo precedent.** `components/popuppos.js`: three pure functions
(`globalCenterX`, `screenFor`, `cardXFor`), zero state, imported as `Pos` in
**10 files** (the base + all 8 standalone popups + `NotificationPopup`/
`NotificationCenter`). It works precisely because geometry math needs no
reactivity and no QML object access.

**Recommendation.** Keep `.js` for stateless helpers (geometry, time
formatting, ICS parsing is already `.mjs` for the same reason). Never put
reactive state, `Process` handling, or QML-item access in `.js` — bindings,
signals, and `Connections` only exist in QML. If a grilling finds logic worth
unit-testing, extracting it to a pure `.js` function is the way to make it
testable (§6).

## 6. Testing/verification: no harness exists; specify per-module checks

**What exists.** Zero `*test*`/`*spec*` files under `config/quickshell/`.
Quickshell ships no test story: the guide's Concepts section covers only
reactive bindings and lazy loading (via `LazyLoader`/`Component`), and the
type reference has no test type. Qt does offer `QtTest.TestCase` +
`qmltestrunner`, but quickshell surfaces require the quickshell engine
(`Quickshell.screens`, `PanelWindow`, layer-shell, service singletons like
`Pipewire`/`Bluetooth`) — they cannot execute outside `qs`, so `TestCase` is
not applicable to windows/popups without a harness nobody has built.

**What verification means here today** (all grounded in repo mechanics):
`watchFiles: true` live-reload on save (Quickshell singleton prop), the
`toggle.sh` socket self-heal path for open/close cycling, and reading the
`quickshell` process log for QML errors/warnings.

**Recommendation for the grillings.** Each deepening spec must name its
verification explicitly:

1. **Reload check**: `quickshell` (or the running instance's live-reload)
   shows no errors after the change.
2. **Socket cycle**: open/close/toggle each touched surface via
   `config/quickshell/scripts/toggle.sh <sock>` (covers the SocketServer +
   coordinator path).
3. **Behavioral spot-check**: the one or two user-visible behaviors the seam
   guards (e.g. anchor-under-module positioning for popups, footer-pill Tab
   action for launchers).
4. **Pure-logic extraction**: any new branching logic that can be pure goes in
   `.js` and gets a `node` runnable check (the `popuppos.js` functions already
   run under plain `node` — the only true unit-test seam in the codebase).

## Suggested seam placement for the grillings (non-binding)

- **Coordinator first** (§3: `closeAllExcept` on `shell.qml` Scope; call from
  the two base types) — unblocks the rest, per map order.
- **Popup shell** (§2: `maxCardHeight` seam; migrate the 8; leave
  `NotificationPopup` alone).
- **Bar-module anchor contract**: already a working seam (`anchorItem` →
  `anchorGX`, inherited by sub-popups by copying); keep the pattern, don't
  re-deepen.
- **Wifi/Bluetooth triple, Handy store** (§4: singleton store + thin views).
- **Display owner**: same store-behind-views shape if it owns compositor state;
  otherwise a base-type subclass.

## Sources

- `config/quickshell/shell.qml`, `components/LauncherBase.qml`,
  `components/popuppos.js`, `menu/ConnectionDropdownBase.qml`,
  `menu/{Battery,Volume,Calendar,ServerMode,Handy,OpenCodeUsage,Display,NotificationCenter,Notification,Confirm,Wifi,Bluetooth}*.qml`,
  `Colors.qml`, `Tokens.qml`, `DnDState.qml` (repo, `main` @ `f34b861`).
- Quickshell guide "QML Language" (structure/imports/creating-types/
  singletons/concepts): `quickshell.org/docs/v0.1.0/guide/qml-language`.
- Quickshell types `Singleton`, `Scope`: `quickshell.org/docs/v0.2.0/types/`.
- Qt docs: "Defining Object Types through QML Documents",
  "Singletons in QML", "Importing JavaScript Resources in QML"
  (`doc.qt.io/qt-6/`).
- Runtime ground truth: `quickshell --version` → 0.3.0; no `qmldir` in
  `config/quickshell/`; no test/spec files under it.
