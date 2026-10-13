# Design proposal LOGO-01 rev 1 — kmDot launcher logo

- Type: addition
- Status: rejected by user; superseded by [rev 2 explorations](quickshell-r1-kmdot-logo-proposal-rev2.md)
- Date: 2026-10-13
- Target: proposed `brand/kmdot` vector mark; replace the app-grid glyph only in the top-bar Kmdot launcher.

## Concept and specification

A compact K with a separate dot connects the mark to the kmDot name. It avoids small monogram details that disappear at bar size.

- Native geometry: 24×24 viewBox. K stem from (5,4) to (5,20), diagonals from (5,12) to (13,4)/(13,20), 2.2px round stroke. Dot at (19,18.5), radius 2.5px.
- Colors: K uses existing `night.text`; dot uses `night.primary`. In runtime these follow semantic theme roles, not hard-coded TokyoNight values.
- Existing launcher pill stays 40×32, radius 16, selected surface `night.selected`. Logo is centered at 24×24 with 8px horizontal and 4px vertical inset.
- Presentation wordmark uses JetBrains Mono 32px/600; the top bar renders the symbol alone.
- Existing app-grid icon remains canonical for Applications elsewhere. No interaction changes, tooltips, or new colors are proposed.

## Validation and preview

Draft only: no canonical library/manifest or runtime changes. Geometry was read from Penpot; all children fit the 480×240 board, and the native logo fits its pill. Export rendered locally and inspected at large and actual bar sizes. SVG text rendering can differ from the Penpot browser.

- File: `Redesign`.
- Isolated page: `Draft · kmDot logo rev 1`, ID `354ba062-72fc-8008-8008-c87c5ee6c348`.
- Board: `kmDot logo proposal rev 1`, ID `354ba062-72fc-8008-8008-c87c5f0197f5`.
- Preview: `/tmp/kmdot-logo-proposal.png` and `/tmp/kmdot-logo-proposal.svg`.

## Decision

The user rejected rev 1 and requested a mark suitable for both the top bar and a future custom lock screen. No rev 1 implementation was deployed. Continue with rev 2 explorations.
