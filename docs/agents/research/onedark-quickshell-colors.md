# One Dark Quickshell color roles

## Sources

- Atom's archived [`one-dark-syntax` `colors.less`](https://github.com/atom/one-dark-syntax/blob/master/styles/colors.less) defines the syntax background, foreground, monochrome steps, syntax accents, and cursor accent as HSL values. It notes the repository was archived in 2018.
- Atom's archived [`syntax-variables.less`](https://github.com/atom/one-dark-syntax/blob/master/styles/syntax-variables.less) assigns those palette values to editor roles. In particular, selection is `lighten(@syntax-background-color, 10%)`; the selected gutter is `lighten(@syntax-bg, 8%)`.
- Atom's archived [`one-dark-ui` `ui-variables-custom.less`](https://github.com/atom/atom/blob/master/packages/one-dark-ui/styles/ui-variables-custom.less) derives its UI background levels from the syntax background; `@level-3-color` is the darkened UI base, which explains the `#21252B` base shade used here.

## Palette facts

The source palette uses `@syntax-hue: 220`, saturation `13%`, and brightness `18%`; this compiles to `#282C34`. Its default text is `@mono-1`, HSL(220, 14%, 71%), or `#ABB2BF`. The official secondary monochrome is HSL(220, 9%, 55%), or `#828997`; the third is HSL(220, 10%, 40%), or `#5C6370`.

The canonical syntax accents compile to cyan `#56B6C2`, blue `#61AFEF`, purple `#C678DD`, green `#98C379`, red `#E06C75`, dark red `#BE5046`, orange `#D19A66`, and yellow `#E5C07B`. The syntax cursor accent is HSL(220, 100%, 66%), or `#528BFF`.

Atom defines selection relative to the background, rather than naming a separate selection hex. Applying the source's 10 percentage point HSL lightening to `#282C34` yields `#3E4452`. The selected gutter uses an 8 point lightening and yields `#3A3F4B`. The latter is a narrow editor gutter selection and is not the broader selection surface used in Quickshell.

## Mapping assessment

The repo's [One Dark mapping](../../../themes/onedark/quickshell.conf) uses official syntax swatches directly: `surface=#282C34`, `surface_alt=#3E4452`, `text=#ABB2BF`, `muted=#5C6370`, `primary=#61AFEF`, `primary_alt=#56B6C2`, `accent=#C678DD`, `success=#98C379`, `warning=#E5C07B`, and `error/urgent=#E06C75`.

Three entries explicitly departed from the palette: `text_alt=#7F848E` was a One Dark Pro comment color rather than Atom's monochrome 2 `#828997`; `border=#4B5263` was not an Atom swatch; and `base=#21252B` is not in the syntax palette itself, but it is derived by Atom's One Dark UI as its level-3 background. The border and outline now use the official monochrome 3 `#5C6370`, which is also the canonical muted/comment swatch.

For the Quickshell roles `surface_high`, `surface_highest`, and `primary_container`, the repo's required constraint is to use the real selection swatch `#3E4452` for all three. This is a deliberate desktop adaptation: the Atom source defines an editor selection role, not M3 cards or a search field. The focus border distinguishes the search field. The `text_alt` role now uses the exact canonical monochrome 2, even though its contrast is under 4.5:1 on the syntax background; keep it for secondary labels and use main text for important copy.

## Contrast

WCAG relative-luminance contrast ratios were calculated from the sRGB hex values in the source and repo mapping:

| Pair | Ratio |
| --- | ---: |
| `#ABB2BF` on `#282C34` (main text on syntax background) | 6.57:1 |
| `#ABB2BF` on `#3E4452` (main text on selection/container) | 4.57:1 |
| `#ABB2BF` on `#4B5263` (the former brighter outline, rejected as a fill) | 3.67:1 |
| `#828997` on `#282C34` (canonical secondary monochrome on syntax background) | 3.93:1 |
| `#61AFEF` on `#282C34` (blue accent on syntax background) | 5.92:1 |
| `#56B6C2` on `#282C34` (cyan accent on syntax background) | 5.91:1 |
| `#C678DD` on `#282C34` (purple accent on syntax background) | 4.75:1 |
| `#E06C75` on `#282C34` (red accent on syntax background) | 4.38:1 |

The official secondary monochrome and red accent do not reach 4.5:1 on the syntax background; reserve them for secondary labels and status accents, and use the main foreground for important copy. The selected container has only a small margin above 4.5:1, supporting the repo's existing constraint to use `#3E4452` rather than a brighter fill. The revised border uses the official `#5C6370` monochrome swatch as a line color; it is not used behind text.
