# Design proposal LOGO-01 rev 3 — integrated KMD monograms

- Status: user selected Folded badge and requested a trailing dot; superseded by [rev 4](quickshell-r1-kmdot-logo-proposal-rev4.md).
- Date: 2026-10-13
- Scope: brand symbol for the existing launcher and potential future lock-screen use. No lock-screen implementation is authorized or implied.

The user liked the abstract direction in rev 2 but asked to integrate KMD. This revision presents three custom vectors at 96px and actual 24px bar size:

1. **Shared stem:** K joins the first vertical of M; the second vertical of M becomes the D spine. One-color compact monogram.
2. **Folded badge — recommended:** the same shared-letter construction with shorter optical height, clipped D corners and a small blue dot in the open lower middle. K, M and D remain legible without a separate wordmark.
3. **Stacked seal:** K and M occupy the upper half, with an angular horizontal D beneath. More badge-like, but its small letter details are less clear at bar size.

## Contract and validation

- Native viewBox 24×24. Round 1.8px strokes, `night.text` foreground; Folded badge's dot uses `night.primary`. Bar uses the existing 40×32 selected launcher pill. No new colors, interactions or tooltips.
- Enlarged lock-screen previews use proportional strokes; they demonstrate logo scalability only.
- Geometry and containment inspected in the isolated 960×432 Penpot board. SVG rendered locally and checked at both sizes. Typography in the comparison uses existing JetBrains Mono 12/14/20/32 sizes. No canonical assets, manifest or runtime changes yet.
- Existing Applications grid icon will remain available elsewhere if a brand mark is selected.

## Preview

- Penpot Redesign page `Draft · kmDot KMD logo rev 3`: `354ba062-72fc-8008-8008-c87dce2085ff`.
- Board `LOGO-01 rev 3 · KMD monograms`: `354ba062-72fc-8008-8008-c87dce37669a`.
- Local SVG and PNG: `/tmp/kmdot-logo-kmd.svg`, `/tmp/kmdot-logo-kmd.png`. These temporary files may disappear on reboot.

Gate A pending: user selection/approval of one direction. After approval, record the exact chosen geometry, promote it to Foundations, update the manifest, implement with theme roles and compare the live bar.
