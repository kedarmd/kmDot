# Quickshell alternate-theme visual validation

Date: 2026-10-14

Status: **Review complete; the documented theming fixes were applied and statically revalidated on 2026-10-14.** This report covers the redesign implementation on `main` after `5486179`, the lock/login replacement work, and the current theme files. Live hardware actions and per-theme SDDM screenshots remain outside this validation pass.

## Remediation follow-up — 2026-10-14

The documented theming findings were addressed in the repository:

- Shared `PillButton` interaction fills now darken from the active surface instead of switching to the brighter border swatch, preserving readable foreground contrast during hover and press.
- `Tokens.mutedText` and `Tokens.errorText` use WCAG contrast checks to retain canonical muted/error swatches where readable and fall back to the theme foreground for copy where necessary. Error borders and icons retain the semantic error color.
- Launcher selected-row subtitle, body and metadata text now use `on_primary_container`; Handy's inactive tab fill is separated from its selected fill.
- Everforest uses `bg_visual` for `primary_container`; Nord uses `nord2`.
- Lock-screen power actions no longer use invalid anchors on `Column` children; the three actions render in stable item delegates.
- The SDDM error message follows the readable foreground while its error border/icon remain red.
- Filled inactive tabs now use the shared raised `surface_alt` treatment across Handy and OpenCode.
- Secondary Handy actions use the shared outlined button variant so `Copy` remains distinct from the editor card while `Save changes` remains the primary filled action.
- Clipboard image preview now treats Enter/Return as copy-and-close, matching the mouse action; Escape still returns to history.

Validation completed with `qmllint` over every affected QML file, `git diff --check`, and a Node-based five-theme contrast/role assertion. All five themes passed muted-copy, error-copy and selected-container checks; the lock action anchor regression check also passed.

## Scope and method

The review treated TokyoNight as the existing baseline and validated the four alternate themes independently:

- Catppuccin Mocha
- Everforest dark hard
- Nord

An isolated headless Hyprland output was used so the running desktop was not modified. Each alternate theme was rendered through the real Quickshell QML with theme-specific `Colors.qml` generation. Sixty-one states were captured per theme, covering the bar, tray, application and command launchers, nested Wi-Fi/Bluetooth/System states, Clipboard, Handy, controls, Display, Sound, Battery, Calendar, Server, usage, notification/reply states, and lock/lock-error states.

The screenshots are stored under `/tmp/kmdot-theme-validation/screenshots/`, with the stage list and provenance in `/tmp/kmdot-theme-validation/capture-inventory.json`. Contact sheets are under `/tmp/kmdot-theme-validation/contact-sheets/`. These temporary artifacts may disappear after reboot; this report records the findings permanently.

Hardware actions, real Bluetooth pairing, secured Wi-Fi authentication, service changes, clipboard writes, destructive Handy actions, and real credential submission were not triggered merely to obtain screenshots. Fixture states validate layout, state presentation, and theme propagation. The lock captures use the native lock surface with a mocked authentication response. The SDDM source and generated palette roles were reviewed, but a live greeter/authentication session was not replaced on the workstation for this pass.

Palette comparisons used the upstream [Catppuccin palette](https://github.com/catppuccin/palette/blob/main/palette.json), [Everforest palette](https://github.com/sainnhe/everforest/blob/master/palette.md), [Nord palette](https://www.nordtheme.com/docs/colors-and-palettes/), and the [TokyoNight night palette](https://github.com/folke/tokyonight.nvim/blob/main/lua/tokyonight/colors/night.lua).

## Historical findings — resolved by the remediation above

The findings below are retained as the original evidence record from the pre-fix review. They are no longer the current implementation status; use the remediation follow-up above for the current result.

## Findings

### High priority: lock-screen power controls are absent in every theme

All lock screenshots omit the approved Shutdown, Restart, and Suspend controls. The delegate at [LockScreenSurface.qml:211](../config/quickshell/menu/LockScreenSurface.qml#L211) is a `Column` whose icon child uses `anchors.horizontalCenter`. Quickshell logs the invalid-anchor warning and the action delegates do not appear.

The credential card, password field, error state, time, branding, wallpaper, and dim layer render correctly. This is a shared lock-screen defect rather than a palette-specific failure. The current lockscreen handoff text claiming that the power-control layout was fixed is therefore stale and must not be treated as validation evidence.

### High priority: filled action buttons lose readable contrast during interaction

[PillButton.qml](../config/quickshell/components/PillButton.qml#L36) changes the fill for hover and press while retaining the active text color. The same pattern is used by Wi-Fi Connect, notification Reply, Handy Save/Delete, and shutdown confirmation controls.

| Theme | Hover contrast | Pressed contrast |
| --- | ---: | ---: |
| Catppuccin | 1.80:1 | 1.80:1 |
| Everforest | 1.54:1 | 1.31:1 |
| Nord | 1.45:1 | 1.69:1 |

The resting buttons are generally legible; the failure appears when the pointer or keyboard activates them.

### Medium priority: Nord error states are weak

Nord error text uses `#BF616A` on `#2E3440`, measuring 3.05:1 on the lock and server error cards and 2.46:1 on the raised card surface. The Nord lock-error and server-error captures show the error copy receding into the card instead of reading as a strong state.

### Medium priority: Everforest and Nord selection containers use the wrong semantic swatch

The raw colors are canonical, but the semantic assignments do not follow the themes' official visual-selection roles:

| Theme | Current `primary_container` | Expected selection/visual role |
| --- | --- | --- |
| Everforest | `#374145` (`bg2`) | `#4C3743` (`bg_visual`) |
| Nord | `#4C566A` (`nord3`) | `#434C5E` (`nord2`) |

Catppuccin and TokyoNight use convincing selection mappings.

### Medium priority: muted text is below readable contrast in most themes

Muted labels and search placeholders are weak on raised surfaces:

| Theme | Muted text on card |
| --- | ---: |
| Catppuccin | 2.57:1 |
| Everforest | 3.09:1 |
| Nord | 1.36:1 |

Nord is most affected. This appears in captions, helper text, timestamps, and low-priority labels.

## Theme-by-theme result

**Catppuccin:** The Mocha swatches match upstream and the panels, launchers, wallpaper, and lock surface are visually coherent. It still inherits the shared interaction-state and muted-text problems.

**Everforest:** The green palette propagates cleanly and the panel bounds remain stable. Selection uses `bg2` instead of the official `bg_visual`, selected secondary text is only 4.30:1, and pressed controls are the weakest of the four alternate palettes.

**Nord:** The blue-gray palette is consistent and geometry is clean. Error red and muted labels are weak, and `nord3` is being used where Nord's selection surface is `nord2`.

## Coverage limits

Toast and reply states were captured for every theme. The notification-center fixture cleared the panel after opening, so its desktop-only screenshots are not valid visual evidence; notification-center validation must be recaptured after reopening the panel. Duplicate Reply buttons in the toast fixture came from supplying both an explicit Reply action and inline-reply metadata.

The SDDM source consumes the generated semantic roles correctly—primary button, on-primary text, secondary placeholder/helper text, and error text—but a live per-theme greeter screenshot was not taken because that requires replacing the active display manager session. Treat login palette propagation as source-reviewed, not fully visually certified.

No repository code was changed during this review. The temporary compositor and Quickshell capture processes were stopped after the captures completed.

