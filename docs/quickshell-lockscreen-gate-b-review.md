# Lockscreen Gate B review — revision 4 approved

Date: 2026-10-13. File: Redesign (`8a4f1bc7-db1f-80ff-8008-c6f6cffb2a27`).
Page: `06 · Lockscreens — R1` (`354ba062-72fc-8008-8008-c8869d73f5c6`).
Status: **LOCKSCREEN-01 rev 4 approved by the user on 2026-10-13** (“Looks good. Please update the handoff docs for this change. I want to start implementing this in a new session.”). Both ready screens, including the final logo placement, are accepted. No runtime deployment. Start implementation from [the handoff plan](quickshell-lockscreen-plan.md).

The sections below preserve revision history. Earlier “awaiting review” entries and geometry are superseded by revisions 3–4 and this final approval. Approval covers the ready screens; expanded pickers, authentication states and runtime behavior remain unvalidated.

## Findings and corrections

- Session title and identity were approximately 19px and 20.5px left of the card center. Both now use centered 376px text boxes, as does the keyboard hint.
- Login title and fields had different left edges (1176 vs 1192). The form now uses one left edge and 24px card padding.
- Login card was 560×672 with excessive whitespace and technical prose. It is now 424×480; the lock card is 424×364. Both center vertically at y=540 on the 1920×1080 boards.
- User/session selectors retained 128px label boxes inside widened 376px controls. Their label boxes now follow the configurable width with the canonical 16px insets.
- Power captions were offset from their icons, and the two screens used different group spacing. Both now use centers at x=832/960/1088, 8px icon-to-caption gaps and a 64px bottom margin.
- Removed the duplicated greeter clock and technical design notes from visible UI. Hidden layers retain those notes. Shortened the login hint to “Press Enter to sign in.”
- Preserved a 48px credential-to-action gap: the existing error component can extend 32px below the ready field while leaving 16px before the action.

## Validation

- Geometry: PASS for the two ready boards. All 73 visible descendants fit their frames. Card insets, centerlines, 376×56 credentials, 40px actions and power alignment checked against live properties with ±0.5px alignment tolerance.
- Tokens/components: PASS for inspected palette, typography, radii and component references. All 15 component heads resolve to approved manifest assets. Existing canonical component internals and typography retained; only permitted text/width and screen layout properties changed. No canonical definitions or tokens changed.
- Visual: ADVISORY. Full-frame PNG exports inspected; no visible overlap or clipping. Canonical credential text ink extends its inherited text box by less than 1px, but remains inside the field. This is not a new component modification.
- Corrections: three bounded rounds covering composition, selector label sizing and brand text boxes; live properties re-read after text layout settled.
- Limits: static TokyoNight ready states at 1920×1080. Responsive layouts, long user/session values, selector menus, full error/authentication states, other themes and runtime authentication are not validated by this review. Error space is reserved, not a claim of completed state design.

## Records and gates

- Gate A: CREDENTIAL-01 rev 1 remains approved. No new system proposal was needed.
- Gate B: revision 2 awaiting user review; not accepted on the agent's authority.
- Manifest: Foundations page `design-system-manifest` plugin data, unchanged.
- Review log: appended revision 2 to Start here page `review-log` plugin data.
- Screen layout contract: updated Lockscreens page `redesign-plan` plugin data.
- Original geometry/text snapshot: Lockscreens page `gate-b-rev1-layout-backup` plugin data (reference snapshot, not a full file backup).

Penpot MCP exposed pages, shapes, geometry, style values, component linkage, canonical components, property edits, plugin metadata and PNG exports. Target boards have no flex/grid layout; composition is positioned explicitly. Comment operations were not needed or exercised. No comments were posted or resolved.

## Follow-up — credential border correction

The user reported uneven password borders on both screens. The earlier visual review missed that the canonical credential field used a centered 2px stroke inside a clipping board: straight edges lost the outer half while rounded corners retained more of the stroke. Restored the already-approved CREDENTIAL-01 rev 1 **inner** stroke alignment on the canonical focus and error fields. Both screen instances inherited the correction automatically. Verified both report `strokeAlignment=inner`, `strokeWidth=2`, and exported each field to confirm an even border. Dimensions, radii and colors are unchanged. Recorded the correction in Penpot's review log and the Lockscreens page `credential-border-fix` metadata. Gate B acceptance remains pending.

## Revision 3 — separate session selection

At the user's request, moved session selection outside the sign-in card to a bottom-left **Desktop session** control. The selected session remains visible (Hyprland in the reference). Intended interaction: activate the control to open an upward picker of SDDM sessions, select without submitting credentials, or Escape to close. The trigger's `interaction-contract` metadata records keyboard and selection behavior; the expanded menu is not drawn or wired in this revision.

Replaced baseline-dependent text chevrons with approved 24px vector instances. Both selector labels now align left with 16px insets; chevrons anchor 16px from the right, vertically centered within the 40px controls. User chevron points down; the footer session chevron points up. The sign-in card is now 424×392, centered at y=540, containing only user/password and sign-in controls. Existing error space remains available.

Geometry and inspected palette/type/component checks pass. Exported and visually inspected the full greeter. No canonical system changes. Updated Penpot review log and screen layout contract; revision 3 awaits Gate B review.

## Revision 4 — Folded badge logo

The user accepted the revised layout (“this is good”) and requested the earlier Folded badge rev 4 logo. Replaced the small KMDOT text on both screens with linked instances of approved `brand/kmdot`, displayed at 48×48 with 48px top/left margins. This is proportional 2× scaling of the native 24px asset, including its 1.8px stroke to 3.6px, preserving the light monogram and primary-colored trailing dot. The canonical definition is unchanged.

Verified component links, proportional path/dot geometry, containment and both full-frame PNG exports. Recorded revision 3 layout acceptance and revision 4 logo addition in Penpot's review log. The logo placement is ready for visual review; no runtime deployment was performed.
