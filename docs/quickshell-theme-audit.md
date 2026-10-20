# Quickshell theme role audit

Date: 2026-10-21

Status: TokyoNight, Catppuccin, and Everforest have been reviewed and approved. Nord remains under individual review. Continue one theme at a time after user review.

## Contract

Each `themes/<theme>/quickshell.conf` defines every role in `theme-switcher/quickshell.roles`. The renderer rejects missing, duplicate, unknown, and malformed values before replacing the deployed palette. `Colors.qml` is generated at sync/theme-switch time; there is no checked-in default palette. Sync requires an explicit theme argument or the user's saved theme selection. Preview JSON goes through the same validator. The Bluetooth `device_inactive` role preserves each approved palette's previous inactive-row swatch; Nord explicitly sets it transparent so connected rows alone carry the selection fill.

`Tokens.qml` contains aliases, sizing and motion. It does not choose replacement text colors based on contrast or manufacture accent containers. Qt text selection, cursor, slider track, status foreground, action button and badge colors all have explicit roles. A rounded button is still an action button; its shape does not turn it into a tag.

Upstream guides take precedence where they specify a role. For unspecified desktop controls, the sources below provide concrete UI precedents. These are documented desktop adaptations, not a claim that each project publishes a universal desktop specification. Transparency for a backdrop is explicitly stored in the theme; geometry and animation remain shell behavior.

## Sources and mappings

### Catppuccin Mocha

[Style guide](https://github.com/catppuccin/catppuccin/blob/main/docs/style-guide.md), plus official VS Code [UI roles](https://github.com/catppuccin/vscode/blob/befc9e6fc41980f4241408f7049755d47c06ff45/packages/catppuccin-vsc/src/theme/uiColors.ts) and [default accent](https://github.com/catppuccin/vscode/blob/befc9e6fc41980f4241408f7049755d47c06ff45/packages/catppuccin-vsc/src/theme/index.ts).

Base supplies panels, Surface 0 inputs/hover surfaces, and Surface 1 slider tracks. Text/Subtext 1/Subtext 0 supply body/secondary/helper copy. The guide supplies Lavender focus borders, Overlay 0 inactive borders, Blue tags, Base text on accents, Rosewater cursors, and Overlay 2 at 25% opacity for selections. Mauve actions/progress follow the official UI port's default accent. Lavender is not advertised as a universal primary color. Borders on desktop controls extend the guide's terminal border convention.

For Quickshell's popup hierarchy, secondary-pane cards use Mantle, while the shell bar remains Base; raised media/thumbnail surfaces use Surface 1. Dividers use Surface 2, matching the official port's menu separators and panel borders. This corrects the previous duplicate Base card and Surface 0 divider assignments.

The workspace active marker has its own `workspace_active` role instead of sharing `pill`: its rounded shape is incidental, while its function is the selected workspace indicator. For Catppuccin it uses Mauve, the official UI port's default accent used for active panel markers. Blue remains reserved for the guide's links and tags/pills. The other theme files currently alias their existing workspace color unchanged; their palettes remain pending individual review.

### TokyoNight Night

[Palette](https://github.com/folke/tokyonight.nvim/blob/main/lua/tokyonight/colors/night.lua), [inherited colors](https://github.com/folke/tokyonight.nvim/blob/main/lua/tokyonight/colors/storm.lua), [derived roles](https://github.com/folke/tokyonight.nvim/blob/main/lua/tokyonight/colors/init.lua), [UI groups](https://github.com/folke/tokyonight.nvim/blob/main/lua/tokyonight/groups/base.lua).

Main background uses `bg`, popup cards use `bg_float`, inputs/hover use `bg_highlight`. Popup selection uses `PmenuSel` (#343a55); text selection uses `bg_visual` (#283457). Outer frames use #292e42 and focused outlines use #7aa2f7, following the upstream [terminal window-border roles](https://github.com/folke/tokyonight.nvim/blob/main/extras/kitty/tokyonight_night.conf). The editor-specific cyan FloatBorder was rejected for general desktop frames during review. Selection swatches are evaluated from upstream formulas, then stored explicitly. Blue with `black` foreground follows `TabLineSel` for active filled controls. Status colors follow diagnostic roles. Helper copy uses `fg_dark`; comment gray remains available for decorative details.

### Everforest Dark Hard

[Palette and role descriptions](https://github.com/sainnhe/everforest/blob/master/palette.md), official UI [material workbench](https://github.com/sainnhe/everforest-vscode/blob/b17f8affe9096f18d209caf2fc26322490e55857/src/workbench/material.ts), [Hard backgrounds](https://github.com/sainnhe/everforest-vscode/blob/b17f8affe9096f18d209caf2fc26322490e55857/src/palette/dark/background/hard.ts), [foregrounds](https://github.com/sainnhe/everforest-vscode/blob/b17f8affe9096f18d209caf2fc26322490e55857/src/palette/dark/foreground.ts).

The Hard palette maps `bg_dim` to the deepest shell background and `bg0` to the main surface. Quickshell popup cards use the workbench's `palette.bg` (#272e33), so its canonical 50% `bg4` selection overlay remains distinct against the card. The highest-raised controls use Hard `bg2` (#374145). Structural separators use `bg4`, while global UI borders use the documented `grey1`. Actions, badges, progress, and active markers use the workbench's green badge color with `bg0` foreground. Text selection follows the Vim Hard `bg_visual` plum. These are distinct roles: a selected list item does not inherit the editor's text selection merely because both are called selection. Helper labels use `grey2`.

### Nord

[Palette guidance](https://www.nordtheme.com/docs/colors-and-palettes/) and [official UI port](https://github.com/nordtheme/visual-studio-code/blob/develop/themes/nord-color-theme.json).

Main background is nord0; popup cards and inputs use nord1. Inner cards and hover surfaces use nord2 to remain distinct from their parent surface; list selection also uses nord2 with nord4 text, matching the official port's inactive selection rows. A separate nord8 outline identifies focused controls; it does not recolor the selected monitor tile. Badges, actions and progress use nord8 with nord0 foreground, following the port's badges and primary buttons. Body text uses nord4; secondary copy uses the port's 90% nord4 description foreground, and helper text follows its 60% nord4 placeholder treatment. Nord3 supplies visible popup frames and separators, following the port's peek-view border and Nord's subtle guide role. Error text retains the explicit diagnostic red instead of being silently replaced with white.

## Cross-application variants

There is no single accent shared by every official port. Ghostty has terminal roles; editors have syntax and application UI roles. This change aligns corresponding roles and records the chosen upstream precedent.

The current Neovim configuration uses Everforest's default contrast rather than Hard. That variant can legitimately differ from the Quickshell palette. Catppuccin uses Mocha and TokyoNight explicitly uses Night.

## Validation

The validation artifacts are under `/tmp/kmdot-theme-audit/`. They are temporary and are not committed desktop captures. Runtime screenshots use the installed Quickshell configuration and real desktop services. Lock screenshots use the same inner lock QML in an ordinary preview surface with fixture authentication state; they do not validate PAM or the secure lock protocol. No credentials or destructive device actions are submitted.

The final capture inventory and results are appended after inspection below.

### TokyoNight review handoff — 2026-10-21

Re-captured the live application launcher, Display, Sound, Calendar, Battery, Wi-Fi, Bluetooth, notification center, Appearance preview and volume OSD after the role corrections. Inspected the rendered panel states and the lock/lock-error preview fixture. Corrected the brightness track override, cyan graph grid/separator misuse, and desktop border mapping found during this pass. Frames now follow upstream terminal inactive borders; focused controls follow active borders.

The current review sheet is `/tmp/kmdot-theme-audit/contact-sheets/tokyonight-review.png`. Full captures are `/tmp/kmdot-theme-audit/screenshots/tokyonight-*.png`. Earlier contact sheets are historical and may show the rejected cyan frame. Runtime logs contain no QML reference/type/assignment errors. Shell syntax and whitespace checks passed; a deliberately incomplete palette was rejected with no generated output. Authentication itself was not exercised.

TokyoNight is synced and active for user review. Other themes remain pending; the earlier multi-theme captures are not approval evidence.

### TokyoNight notification and tray correction

User review exposed states missed by the first handoff: notification group backgrounds matched the outer popup, and tray states were treated as bright badges. Group cards now use bg_highlight against bg_float; bar active fills use the PmenuSel container and its foreground. The server module uses a green status glyph on that neutral container. Removed the introduced hover-outline layer; bar hover uses bg_highlight. DND now shares the other toggles' off-track and thumb roles. Captured and inspected `notifications-corrected.png` and `tray-corrected.png` in the artifact directory; the shell loaded without QML binding errors. These supersede the earlier notification/tray screenshots.

### Catppuccin initial review — 2026-10-21

Corrected the Catppuccin popup card role from Base to Mantle (secondary-pane background), the raised surface role from Surface 0 to Surface 1, and dividers from Surface 0 to Surface 2. The shell bar remains Base, inputs/hover and list selection remain Surface 0, and slider tracks remain Surface 1. This removes role collisions while following the style guide and the official VS Code UI port's Mantle widgets, Surface 2 separators/panel borders, and Surface 0 inputs/selections.

Synced Catppuccin to Quickshell and restarted it without applying the theme to other apps or changing the saved theme selection. Captured the launcher, Display, Sound, Calendar, Battery, Wi-Fi, Bluetooth, notifications, Appearance, volume OSD, and lock preview. Review sheets: `/tmp/kmdot-theme-audit/catppuccin-review/contact.png` and `/tmp/kmdot-theme-audit/catppuccin-review/services.png`; original captures: `/tmp/kmdot-theme-audit/screenshots/catppuccin-*.png`. Quickshell loaded the lock fixture without errors; the runtime log contains expected socket rebind and unavailable system-icon warnings, but no QML binding, type, or reference errors. Authentication was not exercised. This is submitted for user review; Catppuccin is not marked approved yet.

User review identified the active workspace marker as the remaining visible mismatch. Split it from the generic `pill` role and mapped Catppuccin's marker to Mauve; Blue remains the semantic color for tags/pills. Re-synced and restarted Quickshell, then captured `/tmp/kmdot-theme-audit/catppuccin-review/workspaces-corrected.png`. The empty workspace outlines continue to use the same muted color as occupied inactive workspaces, with their empty interiors preserving the distinction.

### Everforest initial review — 2026-10-21

Everforest was already the saved and active theme. Kept its Dark Hard palette. The first visual pass applied the palette's floating-window `bg2` to outer cards; user review showed this made the workbench's standard 50% `bg4` selected-row overlay too faint. The final mapping uses the Everforest UI workbench's `palette.bg` (#272e33) for popup cards and Hard `bg2` (#374145) for the highest-raised controls. Separators use `bg4` (#495156), global borders use documented `grey1` (#859289), green actions/active markers remain the workbench badge green, and text selection remains Vim Hard `bg_visual`.

Synced the updated palette and restarted Quickshell. Captured launcher, Display, Sound, Calendar, Battery, Wi-Fi, Bluetooth, notifications, Appearance, volume OSD and lock preview. Review artifacts: `/tmp/kmdot-theme-audit/everforest-review/contact.png`, `/tmp/kmdot-theme-audit/everforest-review/lock.png`; full screenshots: `/tmp/kmdot-theme-audit/screenshots/everforest-*.png`. No QML binding, type, or reference errors appeared in the runtime log. This Everforest mapping is ready for user review and is not marked approved yet.

User review found the workbench list highlight still hard to distinguish and disconnected Bluetooth devices looked selected because inactive rows had a darker filled tile. Kept the canonical Everforest `bg4` 50% list-selection swatch but restored the popup card background to the workbench `palette.bg`, which gives the selection its intended contrast. Bluetooth connection state uses the success color on the Connected status and checkmark. All device rows retain a surface fill like other panels: connected/busy rows use the selected container, while unconnected rows use `surface_alt`. Captures include `/tmp/kmdot-theme-audit/everforest-review/kmdot-selection.png`, `/tmp/kmdot-theme-audit/everforest-review/bluetooth-corrected.png`, `/tmp/kmdot-theme-audit/everforest-review/corrected-states.png`, `/tmp/kmdot-theme-audit/everforest-review/bluetooth-final.png`, and `/tmp/kmdot-theme-audit/everforest-review/bluetooth-panel-rows.png`. User approved the final Bluetooth row-card appearance.

### Nord review — 2026-10-21

Checked Nord's official palette guidance and Nord VS Code UI port. Kept Nord0 for the shell background, Nord1 for popup/input/hover surfaces and passive borders, Nord2 for selected rows, Nord3 for subtle guides/tracks, and Nord8 for focus/action roles. Set secondary copy to the port's 90% Nord4 description foreground; helper copy remains its 60% Nord4 placeholder treatment. The selected container remains Nord2/Nord4, while focus stays a separate Nord8 outline.

Synced Nord into Quickshell and restarted it without changing the saved active-theme selection. Captured launcher, Display, Sound, Calendar, Battery, Wi-Fi, Bluetooth, notifications, Appearance, volume OSD and lock preview. Screenshots: `/tmp/kmdot-theme-audit/screenshots/nord-*.png`; cropped review panels: `/tmp/kmdot-theme-audit/nord-review/launcher.png`, `/tmp/kmdot-theme-audit/nord-review/bluetooth.png`; contact sheet: `/tmp/kmdot-theme-audit/nord-review/contact.png`. Runtime log had no QML binding, type, or reference errors; only expected icon lookup/socket reconnect warnings. Authentication was not exercised. This first capture set was rejected by user review and is retained as history.

### Nord surface hierarchy correction — 2026-10-21

Review screenshots showed inner notification/device/chart surfaces disappearing because `surface_alt` duplicated the Nord1 popup-card swatch. Remapped `surface_alt` to Nord2, the official brighter shade used for active-line/selection and as a brighter variant for the same UI elements. Re-captured the live Kmdot launcher, notifications, appearance, and battery panels after syncing/restarting Quickshell. Crops: `/tmp/kmdot-theme-audit/nord-review/kmdot-launcher.png`, `/tmp/kmdot-theme-audit/nord-review/notifications.png`, `/tmp/kmdot-theme-audit/nord-review/battery.png`; combined view: `/tmp/kmdot-theme-audit/nord-review/roles-contact.png`. This is a correction for review, not an approval; Nord remains under user review.

Follow-up review exposed missing monochrome SVG icons when `text_alt` carried Nord's 90% alpha: Qt's `#AARRGGBB` string was inserted directly as an SVG color, which QtSvg did not render. The shared vector loader now converts it to RGB and applies the alpha on the image. Disconnected Bluetooth rows are transparent so only connected/busy rows read as selected. Captured and inspected `/tmp/kmdot-theme-audit/nord-review/kmdot-launcher-final.png`, `bluetooth-final.png`, `sound-final.png`, and `notifications-final.png`; launcher icons now render and connected Bluetooth devices have a distinct selected fill. Later user review found borders/separators still too faint; the current pass maps them to Nord3, following the port's peek-view border and Nord's guide swatch. Nord remains under user review.

The Nord control off track/thumb use Nord1/Nord3 respectively, making the off state distinct while using canonical surface and UI-guide swatches. Other themes' `control_off`/`on_control_off` map to the former surface_alt/muted pair so their previous rendering is retained.

User asked whether these direct QML edits alter previously approved themes. Added an explicit `device_inactive` palette role: TokyoNight, Catppuccin, and Everforest map it to the same swatch their Bluetooth rows used before (`surface_alt`); Nord maps it to transparent. Captured the Bluetooth panel under the reviewed themes at `/tmp/kmdot-theme-audit/nord-review/bluetooth-theme-scope.png` and confirmed the approved themes retain their filled inactive rows. The shared SVG fix only handles alpha colors; the approved palettes have opaque `text_alt`, so the rendered icon output is unchanged there.
