# Lockscreen design proposal — CREDENTIAL-01 rev 1

- Type: addition
- Targets: reusable credential field for the Quickshell session lock and SDDM greeter
- Status: Gate A approved and applied
- Date: 2026-10-13

## Need

The R1 design system has `input/default`, `input/focus`, and `input/error`, but those are search inputs with a search icon and an `Esc` hint. The R1 Wi-Fi password error board already demonstrates a 376 × 56 password field, but it is a one-off rectangle rather than a reusable component. Both the in-session lock and the SDDM greeter need a shared, keyboard-first password field that fits the current Quickshell visual language.

## Existing candidates considered

| Candidate | Why it fails |
|---|---|
| `input/default`, `input/focus`, `input/error` | Canonical input variants include search-specific iconography and an `Esc` hint. Reusing them for a password would give the credential control misleading affordances. |
| `05 · States & flows — R1 / Wi-Fi · Password error` | Its field already uses the correct R1 376 × 56 geometry, `night.raised`, `night.radius.16`, `night.type.16`, and a 2px `night.error` outline. It is a single screen example, not an instanceable control with default and focus states. |

## Specification

- Component: `input/credential`, with named state components `default`, `focus`, and `error`.
- States: resting/empty, focused/ready, masked value, error, and authenticating. Error uses the canonical `night.error` border and helper text; authentication prevents duplicate submission and shows a short progress status. Disabled treatment follows the existing 38% opacity rule.
- Dimensions: 376 × 56 logical px in the proposal preview; implementation width fills its parent, with a 56px height. The 376px reference is the existing R1 password-field width.
- Colors: `night.raised` fill, `night.text` entered text, `night.sub` placeholder, `night.primary` 2px focus stroke, `night.error` 2px error stroke and helper text. The implementation maps the same semantic roles through the active `Colors.qml` theme so Catppuccin, Everforest, Nord, One Dark, and TokyoNight all follow the selected theme. The Penpot preview shows canonical TokyoNight R1.
- Typography: JetBrains Mono, 16px/400 for entry and placeholder; JetBrains Mono, 12px/600 for an error message, matching the existing Wi-Fi password error board.
- Spacing: 16px inner horizontal padding and a 16px gap between the canonical 24px lock icon and text. Error helper text sits 16px below the field and uses the existing 12px rhythm.
- Border/radius: 2px inner state stroke when focused or in error; 16px radius (`night.radius.16`). No stroke at rest.
- Alignment: leading 24px canonical `icon/lock`; vertically centered text. No reveal-password affordance. Enter submits; keyboard focus is present when each screen appears.
- Composition: same credential-field states can be used in both lock and login frames. The session-lock screen and SDDM greeter remain separate screens and separate runtime entry points.

## System-consistency analysis

The proposal reuses existing R1 color, type, spacing, radius, and lock-icon definitions. It formalizes the existing Wi-Fi password field geometry and adds a credential-specific component contract without changing search inputs or their behavior. Theme-aware rendering uses the same semantic color roles the Quickshell hook already emits from each selected theme; TokyoNight values remain the Penpot design-system reference palette.

## Self-validation

- Layer 1 (geometry): PASS against the existing 376 × 56 Wi-Fi password field; 16px insets and 24px lock icon follow current R1 spacing and icon sizing.
- Layer 2 (tokens): PASS; every proposed color, text size, radius, spacing, and icon traces to existing R1 canonical tokens/assets. New canonical element is only the reusable credential-field component and its states.
- Layer 3 (visual): PASS on the isolated draft preview; default, focused, and error states are legible and visually distinct. The lock glyph is drawn with vector shapes because the installed icon font did not render the typed glyph in the export.
- Layer 4 (comments): no proposal-specific comments were available on the draft page.

The MCP allowed setting and exporting shape geometry, but does not expose the project's token-binding operation in a way verified for these draft shapes. The preview therefore uses the exact TokyoNight swatch values listed above as a visual proposal; it is not a canonical component or a claim that the draft shapes are linked to token objects.

## Preview

Penpot file `Redesign`, page `Draft · Lockscreen credential proposal rev 1`, board `CREDENTIAL-01 · Credential field states` (isolated; no canonical library or R1 page has been changed).

## Decision (Gate A)

- [x] Approved rev 1 — user replied “Looks good to me.” — 2026-10-13
- [ ] Rejected rev 1 — feedback:

## Applied result

Added to the Foundations page library as separate named state components under `Input / Night R1 / credential`:

| Manifest key | Component ID | State |
|---|---|---|
| `input/credential/default` | `354ba062-72fc-8008-8008-c885e6ae4648` | Placeholder, no stroke |
| `input/credential/focus` | `354ba062-72fc-8008-8008-c885e6f5b40e` | 2px primary focus stroke |
| `input/credential/error` | `354ba062-72fc-8008-8008-c885e74e39b9` | 2px error stroke and helper |

The manifest and review log were updated in Penpot plugin data. Each canonical component was exported and checked for geometry, palette, typography, and its instance of the approved lock icon. No token values were added or changed. During screen review, focus/error borders were corrected from centered to the specified 2px inner alignment to prevent clipping. The final screen designs on `06 · Lockscreens — R1` (LOCKSCREEN-01 rev 4) were approved at Gate B on 2026-10-13, including the separate footer session selector and Folded badge logo. Continue with the [implementation handoff](quickshell-lockscreen-plan.md).
