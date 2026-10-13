# Design proposal LOGO-01 rev 4 — Folded badge with trailing dot

- Status: approved and implemented in the top bar
- Date: 2026-10-13
- User feedback: liked Folded badge; requested the dot after the letters instead of in the middle.

## Specification

Selected direction is the Folded badge KMD monogram. The letter construction is slightly narrower to fit a trailing dot inside the native 24×24 viewBox without reducing vertical size or changing the bar pill.

- Letter path: `M2 5V19M2 12L7.5 5M7.5 19V5L11 10L14.5 5V19M2 12L7.5 19M14.5 5H17L19 8V16L17 19H14.5`.
- Stroke: 1.8px, round caps/joins, existing `night.text`.
- Dot: (22,18), radius 1.5px, existing `night.primary`; no middle dot.
- Native 24×24, existing launcher pill 40×32/radius16/selected surface; centered with 8px horizontal and 4px vertical inset. Runtime colors will follow semantic theme roles.
- Large preview uses proportional geometry/strokes at 96px with a JetBrains Mono 32px wordmark. This is a future lock-screen size illustration, not implementation scope.

## Validation and preview

Both sizes rendered from the live Penpot draft SVG and inspected. The mark fits the native viewBox and bar hit area; all children fit the 640×432 comparison board. No new colors or interactions. Canonical library/manifest and the running launcher remain unchanged pending approval.

- Penpot page `Draft · kmDot Folded badge rev 4`: `354ba062-72fc-8008-8008-c87ea4fb596e`.
- Board `LOGO-01 rev 4 · Folded badge trailing dot`: `354ba062-72fc-8008-8008-c87ea5122f0d`.
- Local preview: `/tmp/kmdot-logo-trailing-dot.png` and `/tmp/kmdot-logo-trailing-dot.svg`.

After approval, promote this exact symbol into Foundations, register it in the manifest, implement a theme-aware vector in the Kmdot bar launcher, sync/restart and compare a fresh screenshot.

## Approval and implementation — 2026-10-13

User approved rev 4: “Yupe, lets use it the topbar now.” Added the canonical Foundations component `Night R1/brand/kmdot`, ID `354ba062-72fc-8008-8008-c87ee54dd13e` (main board `354ba062-72fc-8008-8008-c87ee52ffb25`) and registered `brand/kmdot` in the page manifest. The library mark is 24×24. Live JavaScript manifest checks found no missing component IDs or duplicate token names.

`r1icons.js` stores the approved geometry and component ID. R1Icon supports an accent color so the dot follows `Colors.primary` while the letters follow the existing selected-pill foreground. Kmdot now renders this mark; other Applications grid icons are unchanged. Synced through `./sync/quickshell.sh`, restarted Quickshell, and compared the live bar capture with the canonical export. Startup reached `Configuration Loaded` without QML type/property/binding errors. Captures: `/tmp/kmdot-logo-live.png`, `/tmp/kmdot-logo-canonical.png`; log `/tmp/kmdot-logo-final.log`.

The future lock screen remains outside current implementation scope. Final acceptance of the deployed bar appearance follows user review.
