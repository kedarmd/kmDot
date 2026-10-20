# Everforest Quickshell color roles

Researched 2026-10-20 against Sainnhe's first-party repositories. Everforest defines editor palettes and application-specific styling; it does not publish a universal Material 3 or desktop-shell role mapping. The Quickshell role assignment below is an adaptation.

## Canonical palette

The Vim dark-hard palette defines `bg_dim` #1E2326, `bg0` #272E33, `bg1` #2E383C, `bg2` #374145, `bg3` #414B50, `bg4` #495156, `bg_visual` #4C3743, and `bg_green` #3C4841. Consequently the plum selected controls in the reported screenshot used a real canonical visual-selection swatch; the color was not fabricated. Its broad application to desktop controls was a local design decision. [Palette source](https://github.com/sainnhe/everforest/blob/master/autoload/everforest.vim)

Both first-party projects describe Everforest as green based, warm, and soft. The foreground palette contains green #A7C080, blue #7FBBB3, aqua #83C092, purple #D699B6, and foreground #D3C6AA. The official VS Code port uses green for its `badge` token. [Project description](https://github.com/sainnhe/everforest-vscode), [foreground source](https://github.com/sainnhe/everforest-vscode/blob/master/src/palette/dark/foreground.ts)

## First-party UI behavior

The VS Code material implementation uses green `badge` for progress, prominent buttons, and active borders; green also appears in links and highlighted matches. Dropdowns and secondary buttons have neutral backgrounds. Active list selection uses `fg` over `bg4` with alpha 0x80; in its dark-hard palette `bg4` is #414B50, equivalent to Vim `bg3`. Its surface token names differ from Vim's, so these names must not be copied without checking their values. [Material workbench source](https://github.com/sainnhe/everforest-vscode/blob/master/src/workbench/material.ts), [VS Code dark-hard palette](https://github.com/sainnhe/everforest-vscode/blob/master/src/palette/dark/background/hard.ts)

VS Code's default dark text selection is grey. A green selection option exists, but it uses `dimGreen` #899C40 with transparency, not Vim's #3C4841 `bg_green`. Changing this option does not turn list selection green. Therefore `bg_green` can support a locally chosen tonal green container, but should not be described as the official default selection background. [Configuration defaults](https://github.com/sainnhe/everforest-vscode/blob/master/package.json), [selection implementation](https://github.com/sainnhe/everforest-vscode/blob/master/src/workbench/material.ts)

## Recommended desktop adaptation

| Role | Swatch | Reason |
| --- | --- | --- |
| base | #1E2326 | Vim dark-hard deepest background |
| surface | #272E33 | Canonical main background |
| surface_alt | #2E383C | First raised surface |
| surface_high | #374145 | Next background elevation for cards |
| surface_highest | #414B50 | Higher background elevation for inputs |
| text / selected text | #D3C6AA | Canonical light foreground |
| primary | #A7C080 | Green identity; first-party progress and active UI accent |
| primary_alt | #7FBBB3 | Distinct canonical blue secondary accent |
| accent | #83C092 | Distinct canonical aqua tertiary accent |
| primary_container | #414B50 | Canonical neutral selection base used by official VS Code lists; opaque desktop adaptation |

Using #3C4841 as `primary_container` is a second possible adaptation if a green selected surface is desired: it preserves an exact dark-hard canonical swatch and light foreground. It is not the first-party default list-selection treatment. Either assignment should be documented accurately rather than claimed to be the sole standard.

The recommended changes reduce the blue/aqua emphasis and reserve green for interactive emphasis, while replacing broad plum visual-selection usage with a neutral selection treatment supported by the first-party GUI port. Preserve light text on selected containers, as required by this repository's color-role instructions.

## Applied mapping and validation

Applied the recommended primary, secondary, selection, and elevated-surface values in `themes/everforest/quickshell.conf`. All 21 configured color roles were checked against the dark-hard backgrounds and dark foreground swatches in the upstream Vim palette. No generated intermediary colors were substituted into that file.

Computed sRGB text contrast for the resulting role pairs:

| Pair | Ratio |
| --- | --- |
| Main foreground on main background | 8.15:1 |
| Selected foreground on neutral selected container | 5.30:1 |
| Green primary on main background | 6.88:1 |
| Main foreground on elevated `bg2` | 6.20:1 |
| Secondary `grey2` on `bg1` | 4.93:1 |
| Secondary `grey2` on `bg2` | 4.30:1 |

These measurements validate the main and selected text pairs; they are not a blanket AA claim. The canonical secondary foreground on the brighter `bg2` remains below the 4.5:1 normal-text threshold. Retaining that upstream swatch preserves its intended secondary hierarchy; body and selected text use the lighter foreground instead.

Synced the palette and applied only the Quickshell theme hook to the active Everforest session. Quickshell reported a successful config load, and the Display panel was visually inspected with green primary controls and neutral selected fills.
