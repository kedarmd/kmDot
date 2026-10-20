# TokyoNight Night Quickshell color roles

Researched 2026-10-20 against Folke's first-party TokyoNight sources. TokyoNight defines editor colors and highlight groups, rather than a universal Material 3 desktop-shell standard. This repository's semantic roles are a desktop adaptation.

## Canonical palette and variant

Night inherits Storm's palette, overriding its main background with #1A1B26, dark background with #16161E, and deepest background with #0C0E14. In particular, #292E42 remains Night's canonical `bg_highlight`; using that swatch does not mix Night and Storm variants. [Night definition](https://github.com/folke/tokyonight.nvim/blob/main/lua/tokyonight/colors/night.lua), [inherited palette](https://github.com/folke/tokyonight.nvim/blob/main/lua/tokyonight/colors/storm.lua)

The resolved Night export identifies #3B4261 as `fg_gutter`, #565F89 as `comment`, #C0CAF5 as foreground, and #A9B1D6 as secondary foreground. Its blue #7AA2F7, magenta #BB9AF7, cyan #7DCFFF, and green #9ECE6A already match this repository's accent assignments. #F7768E is canonical red, while the diagnostic `error` token is #DB4B4B. [Resolved Night palette](https://github.com/folke/tokyonight.nvim/blob/main/extras/lua/tokyonight_night.lua)

## First-party UI semantics

Upstream popup and status backgrounds use the dark background; floats also use it by default. Night therefore has #16161E popup/float backgrounds. Its neutral border is #15161E, with #27A1B9 for highlighted floating borders. The visual-selection background resolves to #283457, a published canonical token even though upstream computes it from blue and the main background. [Semantic color setup](https://github.com/folke/tokyonight.nvim/blob/main/lua/tokyonight/colors/init.lua), [default float settings](https://github.com/folke/tokyonight.nvim/blob/main/lua/tokyonight/config.lua)

Cursor-line highlights use `bg_highlight`; visual selections and quick-fix selections use `bg_visual`. Completion menus use dark `bg_popup`, and selected completion rows use a blend based on the gutter foreground. That completion-specific blend should not be confused with a general elevated background. [Highlight definitions](https://github.com/folke/tokyonight.nvim/blob/main/lua/tokyonight/groups/base.lua)

## Recommended desktop adaptation

| Role | Swatch | Reason |
| --- | --- | --- |
| base | #16161E | Canonical dark background |
| surface | #1A1B26 | Night's main background |
| surface_alt | #292E42 | Canonical neutral hover/highlight background |
| surface_high | #16161E | Upstream popup/float treatment; dark overlays are intentional |
| surface_highest | #292E42 | Neutral input background within the dark popup |
| text / selected text | #C0CAF5 | Canonical light foreground |
| text_alt | #A9B1D6 | Canonical secondary foreground |
| primary / primary_alt / accent | #7AA2F7 / #BB9AF7 / #7DCFFF | Existing distinct canonical accents |
| primary_container | #283457 | Official visual selection background |
| error | #DB4B4B | Upstream diagnostic error |
| urgent | #F7768E | Distinct canonical red alert emphasis |

The existing surface roles incorrectly promoted `fg_gutter` #3B4261 into an input background. Replace that with a real background token. The table deliberately follows upstream dark-popup semantics rather than claiming its background ordering is a universal elevation system. If the shell requires brighter cards, #292E42 can remain the card background as a documented local choice, but there is no additional neutral background step between it and the gutter foreground in this palette.

The shell reuses its `border` role as the active workspace fill. Retain the subdued #3B4261 for that shared role and for thin dividers: light text has 6.08:1 contrast on it, versus only 3.83:1 on the canonical comment gray #565F89. This is an explicit desktop adaptation of the gutter token, not a claim that it is upstream's literal `border`. TokyoNight's literal default border is #15161E, while its highlighted float border is teal #27A1B9. Changing these shared roles to either upstream border color would also change active workspace fills, so a literal port would require separating those component roles first.

The primary accents and blue selected container need no correction. Avoid inventing intermediate hex values solely to create a larger surface stack. Preserve light foreground on selected controls.

## Applied mapping and validation

Applied dark popup surfaces (#16161E), neutral input/highlight surfaces (#292E42), and diagnostic red (#DB4B4B) in `themes/tokyonight/quickshell.conf`. Updated the default TokyoNight fallback in `config/quickshell/Colors.qml` to match, so a fresh Quickshell sync does not restore the old mapping. The blue/magenta/cyan accents, visual-selection background, and subdued #3B4261 shared border/workspace fill were retained.

All 21 configured roles were checked against the resolved upstream Night palette. The fallback matches every role. Computed sRGB contrast:

| Pair | Ratio |
| --- | --- |
| Main text on main background | 10.59:1 |
| Main text on dark popup background | 11.14:1 |
| Selected text on visual-selection background | 7.57:1 |
| Secondary text on input background | 6.36:1 |
| Main text on shared border/workspace fill | 6.08:1 |
| Diagnostic red on hover/highlight background | 3.27:1 |

The diagnostic red is a canonical semantic choice, not a normal-text AA claim. Existing `Tokens.errorText` checks contrast against `surface_alt` and substitutes the light foreground when needed for readable error body text. Red remains available for diagnostic icons and accents.

Synced the theme and fallback, then applied TokyoNight with the existing theme switcher. Quickshell loaded successfully, Hyprland reported no config errors, and the Display panel was visually inspected. No invented palette values or shared component styling changes were needed.
