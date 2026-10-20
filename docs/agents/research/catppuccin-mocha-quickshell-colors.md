# Catppuccin Mocha Quickshell color roles

Researched 2026-10-20 against Catppuccin's first-party palette and style guide. Catppuccin specifies general color use, not a Material 3 desktop-shell mapping. The assignments below interpret those recommendations through this repository's Quickshell roles.

## Canonical Mocha palette

The Mocha background stack is Crust `#11111B`, Mantle `#181825`, and Base `#1E1E2E`. Surface0/1/2 are `#313244`, `#45475A`, and `#585B70`. Text/Subtext1/Subtext0 are `#CDD6F4`, `#BAC2DE`, and `#A6ADC8`; Overlay0/1/2 are `#6C7086`, `#7F849C`, and `#9399B2`. [Catppuccin palette](https://github.com/catppuccin/catppuccin#-mocha)

The canonical accents are Rosewater `#F5E0DC`, Pink `#F5C2E7`, Mauve `#CBA6F7`, Red `#F38BA8`, Peach `#FAB387`, Yellow `#F9E2AF`, Green `#A6E3A1`, Teal `#94E2D5`, Sky `#89DCEB`, Sapphire `#74C7EC`, Blue `#89B4FA`, and Lavender `#B4BEFE`. The current theme file uses these exact swatches for its text, status, and accent values. [Catppuccin palette](https://github.com/catppuccin/catppuccin#-mocha)

## First-party usage guidance

Catppuccin recommends Base for the main pane, Crust or Mantle for secondary panes, Surface0/1/2 for surface elements, and Overlay0/1/2 for overlays. It recommends Text for body copy, Subtext0/1 for labels, Overlay1 for subtle text, Blue for links and tags/pills, Green/Yellow/Red for success/warnings/errors, and Overlay2 at 20–30% opacity for selection backgrounds. Its terminal guidance uses Lavender for active borders and Overlay0 for inactive borders. [Catppuccin style guide](https://github.com/catppuccin/catppuccin/blob/main/docs/style-guide.md#general-usage)

The style guide also says Base is the text color “on accent.” That is suitable for bright accent fills such as Lavender or Mauve, but conflicts with this repository's `AGENTS.md` rule that all `on_*` tokens remain light. For this shell, keep `on_primary_container` light as required; if `on_primary` is used over a bright accent fill, its foreground/background pairing needs an explicit decision because Catppuccin's recommended Base foreground is dark and the light Text foreground has poor contrast on pastel accents.

## Current Quickshell mapping

Every current value is an exact canonical Mocha swatch, but some role assignments do not match Catppuccin's first-party usage particularly well:

| Current role | Current swatch | Finding |
| --- | --- | --- |
| `base` / `surface` | Crust `#11111B` / Base `#1E1E2E` | Correctly follows the deepest-to-main background stack. |
| `surface_alt` / `surface_high` | Surface0 `#313244` / Surface1 `#45475A` | The original duplicated Surface0 across two elevations; Surface1 gives cards and dropdowns their next canonical neutral surface step. |
| `surface_highest` | Surface2 `#585B70` | Canonical, but the brightest neutral surface. Main text contrast is 4.62:1 and Subtext1 contrast is 3.77:1, so avoid using it for small secondary text. |
| `primary` / `primary_alt` / `accent` | Blue `#89B4FA` / Lavender `#B4BEFE` / Mauve `#CBA6F7` | All canonical and distinct. Blue now drives common interactive emphasis in line with the style guide's tags/pills and links; Lavender remains available as the active-border secondary accent. Mauve stays the tertiary accent. |
| `primary_container` | Surface1 `#45475A` | Canonical neutral surface, not the palette's documented selection treatment. The guide describes selection as Overlay2 `#9399B2` with 20–30% opacity. An opaque Surface1 fill is a local adaptation and makes selected controls notably brighter than the suggested understated selection. |
| `muted` | Overlay1 `#7F849C` | Uses the guide's subtle-text swatch. It is 4.44:1 on Base and lower on raised surfaces, so use it for secondary labels and prefer Text where content needs stronger contrast. |
| `border` / `divider` | Surface1 `#45475A` / Surface0 `#313244` | Both are canonical neutral surfaces. The active/inactive border guidance instead points to Lavender and Overlay0; retaining surface grays for shared roles can be a deliberate shell adaptation. |
| `on_primary` | Base `#1E1E2E` | Matches Catppuccin's “On Accent” guidance and gives strong contrast over pastel primary fills. The repository specifically requires light text for dark selected containers (`on_primary_container`), which remains light. |

Applied the semantic corrections above in `themes/catppuccin/quickshell.conf`. This is a role correction, not a palette replacement: every value remains an exact Mocha swatch. The theme uses Surface1 for the opaque neutral selected container, with light Text, because the shell requires a dark solid container; this is a documented adaptation of Catppuccin's translucent Overlay2 selection treatment. The shared `border` remains Surface1 because this role also fills active workspace pills; `outline_variant` uses the official inactive-border Overlay0 instead. `on_primary` remains dark Base because it is used over pastel primary fills and has strong contrast, while `on_primary_container` stays light over the dark selected fill as required by the repository.

## Contrast checks

Computed sRGB contrast ratios for current role pairs:

| Pair | Ratio |
| --- | --- |
| Text `#CDD6F4` on Base `#1E1E2E` | 11.34:1 |
| Text on Surface0 `#313244` | 8.69:1 |
| Text on Surface1 `#45475A` | 6.31:1 |
| Text on Surface2 `#585B70` | 4.62:1 |
| Subtext1 `#BAC2DE` on Base | 9.26:1 |
| Subtext1 on Surface1 | 5.15:1 |
| Subtext1 on Surface2 | 3.77:1 |
| Overlay1 `#7F849C` on Base | 4.44:1 |
| Base `#1E1E2E` on Lavender `#B4BEFE` | 9.17:1 |
| Base on Blue `#89B4FA` | 7.79:1 |
| Text `#CDD6F4` on Lavender | 1.24:1 |
| Text on Mauve `#CBA6F7` | 1.40:1 |

Overlay1 follows the official subtle-text guidance and is just below 4.5:1 on Base; avoid it for small copy on raised surfaces. Text remains the stronger choice for content. Catppuccin allows judgment where text sits on colored backgrounds, and the numbers show why dark Base is needed on pastel primary fills. The selected-container foreground remains light over its dark fill per repository instructions.

## Sources

- [Catppuccin canonical palette and palette philosophy](https://github.com/catppuccin/catppuccin)
- [Catppuccin style guide, General Usage](https://github.com/catppuccin/catppuccin/blob/main/docs/style-guide.md#general-usage)
- [Repository Quickshell semantic role requirements](../../../AGENTS.md)
