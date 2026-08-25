---
name: quickshell-module
description: Add or extend a kmDot Quickshell top-bar module, indicator, controller, or its popup/dropdown. Use this when a user requests a new top-bar plugin, widget, module, tray item, bar control, or similar Quickshell feature.
---

# Add a Quickshell Module

Build new top-bar features as native parts of this repository, not as changes made directly under `~/.config`. The repository is the source of truth.

## Workflow

### 1. Inspect before designing

Read the relevant Quickshell rules in `AGENTS.md`, then inspect the closest existing implementations in:

- `config/quickshell/modules/` for bar modules.
- `config/quickshell/menu/` for popups, dropdowns, and launchers.
- `config/quickshell/components/` for reusable UI primitives.
- `config/quickshell/shell.qml` for registration, ordering, cross-closing, and tray placement.
- `themes/*/quickshell.conf` only when a genuinely new theme value may be needed.

Choose the closest implementation as a template rather than inventing a parallel convention:

| Need | Start with |
| --- | --- |
| Reactive hardware state | `Battery.qml`, `Backlight.qml`, or `Audio.qml` |
| Native service model | `Bluetooth.qml` or `Audio.qml` |
| Process or script-backed state | `ServerMode.qml` or `Network.qml` |
| Click-to-open panel | The matching module and `menu/BatteryPopup.qml` or `menu/VolumePopup.qml` |
| Hidden tray item | `HiddenModules.qml` and `ServerMode.qml` |

Prefer a native Quickshell service with reactive properties. Use `Process` when no native service is available. Use a helper script only when shell commands or persistent/background work are required. Scripts are bash, or Node.js when bash cannot express the behavior.

### 2. Resolve the placement

Placement is a required product decision. If the request already states an unambiguous position, record that interpretation and continue. Otherwise ask the user before implementation using these meanings:

| User wording | `shell.qml` target |
| --- | --- |
| left, left side, far left | `leftGroup` |
| middle, center, top center | `centerGroup` |
| right, right side, visible right | `rightGroup` |
| hidden, tray, chevron, collapsed, behind the chevron | Child of `HiddenModules` |

Resolve relative wording such as “next to Battery”, “before Wi-Fi”, or “after the clock” against the existing module in `shell.qml`. Ask for confirmation if the anchor or side is ambiguous. Preserve the requested order; the order of children in each `Row` is the visual order.

For a hidden-tray module with a popup, bind `HiddenModules.stayOpen` to that popup's `opened` state in `shell.qml`, so the tray does not collapse while the popup is open.

### 3. Clarify behavior

Before planning, establish only the missing decisions:

- Display-only, or interactive?
- What do left click, right click, and wheel actions do?
- Does click open a popup/dropdown, and should it remain open after an action?
- What is the data source, refresh policy, and failure/empty state?
- Does the feature need a socket, a helper script, permissions, or a background process?
- What should the tooltip, icon, label, active state, disabled state, and loading state show?

Do not ask questions that the request and repository already answer. If a sensible default exists, state it in the plan instead of creating unnecessary interaction.

### 4. Present the implementation plan

Before editing, present a concise, file-level plan and wait for user approval. Include:

- The module and popup/script files to create or modify.
- The exact `shell.qml` group and insertion point.
- The data source and state model.
- Interaction and cross-close behavior.
- Theme/token usage.
- Deployment and verification commands.

Do not edit files before approval unless the user explicitly asks for immediate implementation.

### 5. Implement the smallest complete slice

For a normal bar module:

- Use an `Item` root with `implicitHeight: 30` and width driven by the displayed content.
- Add `ModulePill`, wiring its `hovered` and `pressed` properties to the module `MouseArea`.
- Use `StateLayer` through the shared components rather than creating a one-off hover treatment.
- Expose `required property var tooltip` unless the module is intentionally tooltip-free or uses a nullable tooltip like `ServerMode.qml`.
- Use `Tokens` semantic roles and `Colors` text roles. Hardcode no theme colors or per-theme visual assumptions.
- Use the existing Nerd Font family and established glyph conventions.
- Keep state reactive where possible; avoid polling when a native signal or property exists.

For a popup or dropdown:

- Follow the existing `PanelWindow` overlay pattern in the closest popup.
- Add the socket using the `kmdot-<name>` naming convention and toggle it through `config/quickshell/scripts/toggle.sh`.
- Register the popup on the `shell.qml` scope and wire cross-closing with launchers and other popups.
- Wire the `anchorItem` seam so the card centers under the clicked module: give the module a `popup`/`dropdown` property from `shell.qml`, set `<popup>.anchorItem = root` before exec'ing `toggle.sh`, and position the card via `components/popuppos.js` (`applyAnchor()` + the `anchorGX` x-binding, see any existing popup). Sub-popups opened from it inherit by copying `anchorGX` before `.open()`.
- Keep the card, scrim, focus, Escape handling, and scrolling behavior consistent with the closest existing component. Do not put `clip: true` on a rounded popup card.
- Use `LauncherBase` only when the feature is genuinely a picker/search flow; use the popup patterns for controls and status panels.

For scripts or processes:

- Keep scripts under `config/quickshell/scripts/`.
- Use bash or Node.js only, with safe quoting and clear failure handling.
- Make new shell scripts executable in the repository with `chmod +x`.
- Avoid writing credentials, private URLs, or machine-local state into the repository.

### 6. Theme and palette review

Treat theme compatibility as part of completion:

- First use an existing semantic role from `Tokens` or `Colors`.
- Add a new role only if the feature cannot be expressed with the existing palette.
- If a new role is necessary, update the generator/source theme files consistently for every supported theme and document the semantic meaning.
- Check active, selected, warning, error, disabled, and loading states for readable contrast.
- Avoid property names matching `on` plus an uppercase letter; QML interprets those as signal handlers. Use the repository's safe `on_*` naming style for such token names.

### 7. Deploy and verify

After implementation is approved:

1. Run `./sync/quickshell.sh` to deploy the repository configuration.
2. Restart Quickshell using the established repository launch pattern. If invoking `pkill`, use `pkill -x quickshell || true` so an already-stopped process does not abort the workflow.
3. Check Quickshell stderr or the relevant user journal for QML import, binding, socket, and process errors.
4. Verify the requested placement, tooltip, interactions, popup focus, socket toggle, and failure states.
5. Exercise the feature on more than one supported theme. For monitor-aware popups, test the module on each monitor.

Do not claim runtime verification when Quickshell or the relevant hardware/service is unavailable. Report what was and was not verified.

## Completion checklist

- [ ] Requirement and placement are explicit.
- [ ] Module is registered in the correct `shell.qml` group and order.
- [ ] Hidden-tray modules have the required `stayOpen` behavior.
- [ ] Shared components and reactive services are used where applicable.
- [ ] Theme colors come from `Tokens`/`Colors` and states remain readable.
- [ ] Popup sockets, scope wiring, focus, and cross-closing are complete.
- [ ] Scripts use bash or Node.js and are executable.
- [ ] No private machine-local data was added to the repo.
- [ ] `./sync/quickshell.sh` was run after approval.
- [ ] Runtime and theme verification results are reported accurately.
- [ ] `AGENTS.md` is updated only if the feature introduces a lasting convention or important quirk.
