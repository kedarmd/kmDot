# Quickshell theme role audit

Date: 2026-10-21

Status: TokyoNight was reviewed first. Catppuccin is now the current review scope; other theme mappings below remain draft research and are not approved or declared complete. Continue one theme at a time after user review.

## Contract

Each `themes/<theme>/quickshell.conf` defines every role in `theme-switcher/quickshell.roles`. The renderer rejects missing, duplicate, unknown, and malformed values before replacing the deployed palette. `Colors.qml` is generated at sync/theme-switch time; there is no checked-in default palette. Sync requires an explicit theme argument or the user's saved theme selection. Preview JSON goes through the same validator.

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

Panels use bg0; secondary surfaces use bg1. Actions, badges and progress use the workbench's green badge color, with bg0 foreground. List selection follows workbench bg4 at 50% opacity. Text selection follows the Vim Hard `bg_visual` plum. These are distinct roles: a selected list item does not inherit the editor's text selection merely because both are called selection. Borders use bg4; the green active outline follows the workbench active-focus marker. Helper labels use grey2.

### Nord

[Palette guidance](https://www.nordtheme.com/docs/colors-and-palettes/) and [official UI port](https://github.com/nordtheme/visual-studio-code/blob/develop/themes/nord-color-theme.json).

Main background is nord0, popup/input surfaces nord1, list selection nord2 with nord4 text. Selection follows the port's inactive selection container; a separate nord8 focus outline identifies the selected monitor/input. Badges/actions/progress use nord8 with nord0 foreground. This follows the port's badges, buttons and active markers. Body text uses nord4, not the brighter nord6 reserved for emphasis. Helper text follows the port's 60% nord4 placeholder treatment. Error text retains the explicit diagnostic red instead of being silently replaced with white.

### Original One Dark UI

Atom [UI variables](https://github.com/atom/one-dark-ui/blob/master/styles/ui-variables.less), [derived UI roles](https://github.com/atom/one-dark-ui/blob/master/styles/ui-variables-custom.less), [original syntax input](https://github.com/atom/one-dark-syntax/blob/master/styles/colors.less).

The UI formulas were evaluated with the original syntax background HSL(220,13%,18%). Main/background/popup/input roles are #282c34/#21252b/#252830/#1b1d23. Body text is UI #9da5b4; list selection #3a3f4b with white selected text. Controls use #568af2; accent copy uses #759ef2; buttons/badges use #4d78cc with white text. Syntax blue #61afef is not substituted for the UI accent. Diagnostic foregrounds and semantic button backgrounds retain their separate upstream values. Hover emphasizes the existing focus border rather than computing a new color.

## Cross-application variants

There is no single accent shared by every official port. Ghostty has terminal roles; editors have syntax and application UI roles. This change aligns corresponding roles and records the chosen upstream precedent.

The current Neovim configuration uses Everforest's default contrast rather than Hard, and `navarasu/onedark.nvim` with `style = "darker"` rather than original Atom One Dark. Those variants can legitimately differ from these palettes. This audit preserves those app configurations; changing them would be a separate variant-alignment decision. Catppuccin uses Mocha and TokyoNight explicitly uses Night.

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
