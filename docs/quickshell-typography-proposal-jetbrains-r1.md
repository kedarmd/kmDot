# Proposal: JetBrains Nerd Font for Quickshell R1

Revision: 1
Status: Implemented; final screen review pending
Target: Redesign file, Foundations — R1 typography system and all R1 Quickshell screens

## Proposal

Replace Manrope as the R1 interface typeface with **JetBrainsMono Nerd Font** for all interface text: panel and launcher titles, labels, network names, descriptions, input text, and numeric readouts. Keep the existing typography sizes, weights, colors, spacing, and component geometry for the first comparison pass. Continue using the same Nerd Font family for icon glyphs, and keep vector icons such as the Wi-Fi outline independent of text fonts.

## Reason

The current implementation and approved R1 designs use Manrope, but the user prefers JetBrains Nerd Font. This changes the shared typography choice and should be applied consistently across Penpot and the implementation rather than creating a mixed type system.

## Expected impact

JetBrains Mono is monospaced and has wider text metrics than Manrope. Some labels may use more horizontal space or wrap sooner. After approval, update Penpot typography references, then implement the family across Quickshell and review the screens for clipping, wrapping, and alignment. Any geometry adjustments required by the new metrics will be made to preserve the existing component structure and visual hierarchy.

## Validation plan

1. Update the R1 typography definition and representative screen designs after approval.
2. Check the Wi-Fi panel, launcher, and text-heavy panels in Penpot for readable wrapping and alignment.
3. Apply the approved family across Quickshell UI text while retaining the existing icon glyph mapping.
4. Sync and review the same screens live for clipping, line breaks, and QML/font loading issues.

## Approval requested

Approved: **Revision 1: use JetBrainsMono Nerd Font for all Quickshell interface text, preserve current size/weight/layout tokens initially, and revalidate geometry for its monospaced metrics**.

## Implementation and validation

- Updated all 863 text objects on the six R1 pages to Penpot's JetBrains Mono family and updated all seven R1 shared typography styles. No R1 text objects or shared R1 styles remain on Manrope.
- Kept the existing type sizes and weights. Adjusted seven text bounds on the panels and states pages where the new font metrics exceeded the original boxes.
- The final Penpot bounds check found no text overflow candidates across the six R1 pages.
- Updated Quickshell QML text to `JetBrainsMono Nerd Font`, retained `JetBrainsMono Nerd Font Propo` for existing icon glyphs, and removed the bundled Manrope font. The runtime install already includes `ttf-jetbrains-mono-nerd`.
- Synced and restarted Quickshell. Reviewed live Wi-Fi, Applications launcher, Sound, and Battery surfaces. The visible text fits, including the Battery profile buttons. Quickshell loaded without QML errors or font warnings; existing missing desktop-icon warnings remain.
- `git diff --check` passes. Automated tests were not run.

Final visual review of the implementation is still pending user feedback.
