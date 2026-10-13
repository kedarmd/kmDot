# Design proposal LOGO-01 rev 2 — bar and lock-screen explorations

- Status: superseded by [rev 3 KMD monograms](quickshell-r1-kmdot-logo-proposal-rev3.md). User liked the direction and requested integrated KMD letters; no canonical approval or deployment.
- Date: 2026-10-13
- Scope: reusable `brand/kmdot` symbol. Lock-screen scenes are size previews, not a proposed lock-screen implementation.

The user rejected the K-and-dot rev 1 and asked for a logo that works at bar scale and on a future custom lock screen. Rev 2 explores abstract geometric marks with the existing theme foreground/accent colors.

| Direction | Native 24×24 geometry | Rationale |
| --- | --- | --- |
| 01 Portal — recommended | Round 2.4px strokes: `M8 3L2.5 8.5V15.5L8 21` and `M16 3L21.5 8.5V15.5L16 21`; centered dot (12,12), radius 3 | Symmetric bracket emblem suggests code and frames the dot without literal letters. |
| 02 Facet | Round 2.2px diamond `M12 2L22 12L12 22L2 12Z`; filled inner diamond (6.5,12), (12,6.5), (17.5,12), (12,17.5) | A compact geometric badge with a clear silhouette. |
| 03 Orbit | Round 2.5px open ring `M20 14A8.2 8.2 0 1 1 10 3.9`; dot (18.5,5.5), radius 3 | Softer circular mark, visually distinct from the angular alternatives. |

## Shared contract and validation

- Existing `night.text` for emblem strokes; `night.primary` for the dot/inner diamond. Supports a single-color export without requiring gradients or effects. Runtime should follow semantic theme colors.
- Native symbol 24×24, centered inside the existing 40×32 launcher pill with 16px corners and selected fill. The mockups also show 96×96 marks on dark surfaces to assess future lock-screen use; stroke widths are scaled proportionally.
- No changes to Applications' grid icon elsewhere, no launcher interaction changes, no new color tokens.
- Geometry inspected through Penpot; native marks fit the hit areas and children fit the 960×432 draft board. Round caps/joins and minimal detail remain legible at actual bar size. Live draft SVG exported and rendered locally; labels use JetBrains Mono 12/14/20/32.
- This is an isolated draft. Canonical library/manifest and runtime are unchanged. Human selection and approval are required before promoting one direction.

## Preview references

- Penpot Redesign page `Draft · kmDot logo rev 2 explorations`: `354ba062-72fc-8008-8008-c87d4c2baf1c`.
- Board `LOGO-01 rev 2 · bar and lock-screen explorations`: `354ba062-72fc-8008-8008-c87d4c3c3997`.
- Local preview: `/tmp/kmdot-logo-options.png` and `/tmp/kmdot-logo-options.svg`; temporary files may disappear after reboot.

Next decision: select Portal, Facet or Orbit, or provide feedback for another revision. No future lock-screen scope is implied by approval of the logo.
