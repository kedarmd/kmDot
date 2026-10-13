# Design proposal DND-01 rev 1 — top-bar Do not disturb state

- Type: addition
- Targets: proposed `icon/bell-off` and `bar/dnd-on` assets in the R1 design system
- Status: approved and implemented; final visual acceptance pending
- Date: 2026-10-13

## Need

The normal notification bell uses the approved vector, but DND-on uses a different font glyph and an error container. DND is an intentional preference. Give it a coherent vector and the existing blue tonal selected surface.

## Existing candidates considered

| Candidate | Result |
| --- | --- |
| R1 `icon/bell` | Reuse its exact geometry; it does not indicate silencing alone. |
| Current crossed-out font glyph | Inconsistent stroke and shape compared with the vector library. |
| Error container | Wrong emphasis for a user-selected mode; reuse the existing selected token. |

## Specification

- Off: existing 24px bell, `night.text`, transparent 36×32 hit area.
- On: proposed 24px bell-off, based on the canonical bell path with an added diagonal from (3,3) to (21,21). Round caps/joins and 1.8px stroke match the existing icon.
- Selected pill: 36×32, 16px radius, `night.selected` (#283457), foreground `night.text` (#C0CAF5). Icon centered with 6px horizontal and 4px vertical inset.
- No notification dot while DND is on. Off-state unread dot retains the approved 6px primary treatment.
- Hover/pressed behavior reuses the existing bar StateLayer; no new color token or interaction is proposed. Clicking still opens Notification Center, where the DND switch lives. No tooltip.
- Placement remains immediately right of the centered calendar/clock.

## System consistency and validation

- No new tokens. All draft fills/strokes use existing `night.surface`, `night.selected` and `night.text` values.
- Geometry checked through Penpot: 480×224 draft board; both icons 24×24 and contained in their 36×32 hit areas. All immediate children fit the board.
- Typography: JetBrains Mono 24px title and 14px state labels.
- Visual: exported the live draft to SVG and rendered locally; both states inspected. SVG text rasterization may differ from the Penpot browser.
- The new icon and variant are drafts, not canonical components; canonical Foundations assets and the manifest have not been changed. No runtime change has been deployed.

## Preview

- Penpot file `Redesign`, page `Draft · DND state proposal rev 1` (`354ba062-72fc-8008-8008-c87a7eac83d3`).
- Board `Proposal DND rev 1 · off and on` (`354ba062-72fc-8008-8008-c87a8da60f7e`).
- Local preview: `/tmp/kmdot-dnd-proposal.png`; SVG: `/tmp/kmdot-dnd-proposal.svg`. These temporary artifacts may disappear on reboot.

## Decision

Gate A approved on 2026-10-13: user said “looks good I think, use your best judgement.” Rev 1 was promoted to Foundations and its component IDs added to the page's design-system manifest:

- `icon/bell-off`: `354ba062-72fc-8008-8008-c87b2b9fbb23`; main board `354ba062-72fc-8008-8008-c87b2b6a8a43`.
- `bar/dnd-on`: `354ba062-72fc-8008-8008-c87b2bc509c1`; main board `354ba062-72fc-8008-8008-c87b2ba30c18`.

Post-implementation validation: icon 24×24; pill 36×32; icon inset 6px/4px, canonically linked to bell-off. Fill #283457 and light foreground match approved tokens. JavaScript validation of the live manifest found no duplicate token names, missing component IDs, or missing required color tokens (the repo prohibits Python). Canonical export and live screenshot were inspected. `Dnd.qml` now uses the vector bell-off and primary container; unread dot remains hidden while DND is enabled. Synced and restarted normally, reaching `Configuration Loaded` without QML type/property/binding errors. Captures: `/tmp/kmdot-dnd-canonical.png`, `/tmp/kmdot-dnd-live.png`; log: `/tmp/kmdot-dnd-final.log`.

Final visual acceptance is pending the user's review of the implemented state. No other design-system changes were made.
