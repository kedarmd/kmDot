# Nord Quickshell color roles

Researched 2026-10-20 against Nord's official palette and color usage guide. Nord describes its UI recommendations as flexible and its design as minimal and flat. The Quickshell role mapping is an adaptation of those guidelines to this repository's semantic roles.

## Official palette guidance

Nord0 `#2E3440` is the dark background. Nord1 `#3B4252` is the first raised shade and is specifically recommended for bars, panels, popups, form controls, and passive borders. Nord2 `#434C5E` is used for selection and highlighting. Nord3 `#4C566A` is for guides, comments, and low emphasis UI. [Nord Colors and Palettes](https://www.nordtheme.com/docs/colors-and-palettes/)

For dark designs, Nord6 `#ECEFF4` is the bright UI text and plain-text color, while Nord5 `#E5E9F0` is the subtler text shade. Nord4 `#D8DEE9` is used for caret and syntax colors. The previous Quickshell `text` value was Nord4, below its `text_alt` Nord5; that inverted the intended hierarchy. [Nord Colors and Palettes](https://www.nordtheme.com/docs/colors-and-palettes/)

Frost Nord8 `#88C0D0` is the primary UI accent. Nord9 `#81A1C1` is a secondary accent, and Nord7 `#8FBCBB` is a distinct high-attention companion to Nord8. Aurora maps Nord11/Nord13/Nord14 to error/warning/success. [Nord Colors and Palettes](https://www.nordtheme.com/docs/colors-and-palettes/)

## Applied Quickshell mapping

| Role | Swatch | Reason |
|---|---|---|
| `base` / `surface` | Nord0 `#2E3440` | Nord's flat dark background; the repository explicitly allows both roles to use Nord0. |
| `surface_alt` / `surface_high` | Nord1 `#3B4252` | Keep the intentionally flat first raised surface used for panels, popups, and controls. Nord has a compact dark surface stack. |
| `surface_highest` / `primary_container` | Nord2 `#434C5E` | Canonical selection/highlight shade, used for the strongest neutral surface and selected controls. |
| `text` / `text_alt` | Nord6 `#ECEFF4` / Nord5 `#E5E9F0` | Restores the official prominent-to-subtle text order. |
| `muted` | Nord3 `#4C566A` | Canonical guide/comment tone, reserved for low-emphasis marks. |
| `primary` / `primary_alt` / `accent` | Nord8 `#88C0D0` / Nord9 `#81A1C1` / Nord7 `#8FBCBB` | Matches the official Frost accent meanings while keeping all accents distinct. |
| `success` / `warning` / `error` | Nord14 `#A3BE8C` / Nord13 `#EBCB8B` / Nord11 `#BF616A` | Matches the official Aurora status meanings. |
| `border` / `divider` / `outline_variant` | Nord1 `#3B4252` | Uses Nord's documented passive-border shade rather than its selection color. |
| `on_primary_container` | Nord6 `#ECEFF4` | Light text remains on the dark selected container, as required by this repository. |
| `on_primary` | Nord0 `#2E3440` | Dark text on the bright Nord8 primary accent. |

The theme therefore changes only the main foreground, selected-container foreground, and passive border roles. The shared `surface_alt` and `surface_high` values intentionally repeat Nord1 to follow Nord's flat surface guidance instead of inventing extra shades. Nord2 remains the selected container, not a passive border.

## Contrast checks

Computed sRGB contrast ratios for the applied palette:

| Pair | Ratio |
|---|---:|
| Nord6 on Nord0 | 10.84:1 |
| Nord5 on Nord0 | 10.26:1 |
| Nord6 on Nord1 | 8.73:1 |
| Nord5 on Nord1 | 8.26:1 |
| Nord6 on Nord2 | 7.49:1 |
| Nord5 on Nord2 | 7.09:1 |
| Nord8 on Nord0 | 6.24:1 |
| Nord9 on Nord0 | 4.64:1 |
| Nord7 on Nord0 | 5.99:1 |
| Nord3 on Nord0 | 1.69:1 |
| Nord11 on Nord0 | 3.05:1 |

Nord3 and Nord11 remain decorative/status colors, not normal text colors. The shell's contrast-aware error text helper supplies readable foreground for error copy. Nord's shade pairings retain strong contrast for body and selected text.

## Sources

- [Nord Colors and Palettes](https://www.nordtheme.com/docs/colors-and-palettes/)
- [Nord official source palette](https://github.com/nordtheme/nord/blob/develop/src/nord.styl)
- Repository role requirements in [`AGENTS.md`](../../../AGENTS.md)
