# Quickshell design language

Use this guide when creating, restyling, or reviewing a Quickshell launcher,
popup, dropdown, or control. The visual reference is the oma-cast launcher
imported into kmDot; this guide records the adaptations approved for the
surrounding kmDot panels.

## Visual direction

- Treat the migrated oma-cast launcher as the reference for hierarchy,
  typography, spacing, surfaces, and selected states. See
  [`config/quickshell/launcher/UPSTREAM.md`](../config/quickshell/launcher/UPSTREAM.md)
  for provenance and the integration boundary.
- Carry the same visual language through every part of a panel. Review its
  buttons, tabs, dropdowns, sliders, rows, and feedback states along with its
  card and heading.
- Reuse `Colors`, `Tokens`, `PillButton`, `SliderBar`, and shared popup/launcher
  components. Use semantic theme roles; do not add one-off colors or global
  palette values for local styling.
- Keep the typography of each established surface. The imported launcher uses
  its oma-cast font treatment; kmDot utility panels keep their existing
  JetBrains Mono treatment. Do not flatten those distinct surfaces into one
  global font rule.

## Shape and layout

- Prefer restrained geometry: launcher and utility cards use about 20px
  corners, rows use 12–16px corners, and ordinary action buttons use 8px
  corners. Reserve fully rounded pills for controls that represent a grouped
  choice or mode.
- Keep action buttons compact and visually consistent with neighboring
  controls. Avoid making every button a capsule.
- Tabs in the same group share the same height and available width. Their
  selected state must not change their geometry.
- Opening a dropdown or menu overlays its parent surface; it does not resize or
  reflow the parent. Give the menu its own surface, outline, and bounded content
  area, and keep it above nearby content.
- Use spacing and surface contrast to establish hierarchy. Do not add large
  empty gaps or extra bottom padding without a content or alignment reason.

## Control states and affordances

- Make active, hovered, focused, disabled, and pressed states distinct.
  Selection persists while another item is hovered. Use the selected fill and
  foreground for the active entry, a separate hover surface for the hovered
  entry, and a checkmark for selected menu options where it clarifies state.
- Disabled controls must look and behave disabled. A disabled slider must not
  retain a vivid active fill or pointer affordance that suggests it can change.
- Use a trailing chevron only when activating the row opens another view or
  reveals detail. Use a checkmark or status text for selected/connected state;
  omit decorative chevrons from rows that perform an action directly.
- Keep status and useful data in the panel when they aid a decision. Avoid
  tooltip badges or decorative metadata that duplicate visible content.
- Preserve keyboard focus and activation feedback alongside mouse hover and
  click behavior.

## Review before finishing

Inspect the whole panel, including the states that are easy to overlook:

1. Compare its surface, type, spacing, and control shapes with the migrated
   oma-cast launcher and nearby approved kmDot panels.
2. Check every tab, button, dropdown option, row affordance, slider, and
   disabled state. Verify selected styling remains visible when another option
   is hovered.
3. Open dropdowns and expanded content and confirm the parent geometry stays
   fixed, content stays within its surface, and the menu remains legible.
4. Inspect a live rendering at the intended display size and scale when
   available. Review the whole panel rather than only the element called out
   in feedback.
5. Reuse existing semantic theme roles and shared components; update the shared
   component when the same correction applies across panels.
