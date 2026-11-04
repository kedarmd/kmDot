---
name: kmdot-quickshell-ui
description: Design, implement, restyle, or review Quickshell UI in the kmDot repository using its vendored Kcast launcher as the visual and interaction reference.
metadata:
  short-description: kmDot Quickshell UI standard
---

# kmDot Quickshell UI

Use this skill for UI work in `config/quickshell/` in kmDot: launchers, popups, dropdowns, bar controls, and shared visual components. Kcast (the local fork of oma-cast) is the reference standard for visual hierarchy, control states, spacing, and keyboard interaction. Apply its patterns to kmDot surfaces while preserving kmDot's shell lifecycle, theme system, and domain behavior.

## Read the local references

Before changing UI, inspect the relevant existing components and read:

- [`docs/quickshell-design-language.md`](../../../docs/quickshell-design-language.md) for approved geometry and kmDot adaptations.
- [`config/quickshell/launcher/UPSTREAM.md`](../../../config/quickshell/launcher/UPSTREAM.md) for Kcast provenance and integration boundaries.
- The corresponding reference source under `/home/kedarmd/dev/oma-cast/plugin/ui/` and `plugin/compat/` when that checkout is available. The imported copy is under `config/quickshell/launcher/plugin/`.

When changing theme roles or palette values, follow the theme audit pointer in `AGENTS.md` if its target is present; do not invent palette values to fill a missing reference.

## Design and interaction standard

- Preserve the Kcast visual hierarchy: a clear header, legible search or title, focused result list, compact footer, restrained surfaces, and purposeful secondary panels. Prefer the established Kcast type treatment within the launcher. Other kmDot panels may retain their established typography when the design guide calls for it.
- Use semantic `Colors` roles and existing `Tokens` aliases. Reuse shared components such as `LauncherBase`, `CastLauncherView`, `PillButton`, `SliderBar`, and popup positioning helpers when they fit. Keep role foreground/background pairs explicit and theme driven.
- Match the reference geometry: launcher cards around 680×520 with 20px corners; ordinary result rows around 56px high with 10px corners; secondary panels around 14px corners; compact actions around 8px corners. Treat these as reference dimensions, adapt to content and screen bounds, and scale consistently where the component already supports scaling.
- Keep state styling coherent: selected, hovered, focused, pressed, disabled, busy, and error states must be distinguishable. Hover must not erase persistent selection. Disabled controls must not look interactive. Use checkmarks/status for state and chevrons only for navigation or disclosure.
- Keep keyboard navigation and activation first-class alongside pointer use. Provide visible key hints when they help, preserve focus through state changes, and make Escape/back behavior predictable for nested views and prompts.
- Bound scrollable content to its surface. Clip the scrolling viewport rather than the rounded outer card when clipping would square its corners. Menus and expanded panels should overlay, not resize their parent.
- Use transitions sparingly and respect the existing reduced-motion setting. Avoid decorative metadata, empty space, one-off colors, and control shapes that obscure their purpose.

## kmDot integration boundaries

Kcast is the UI and interaction reference, not the owner of the kmDot shell. Keep launcher and popup lifecycle, socket naming, shortcut ownership, `scope` coordination, theme loading, and domain services in kmDot's existing architecture. Do not import standalone Kcast runtime services, installers, or lifecycle assumptions when implementing a kmDot surface. Follow `config/quickshell/launcher/UPSTREAM.md` for imports and source updates.

For new UI, first find the closest kmDot component and extend its existing seam when that preserves the reference behavior. For a restyle, inspect the complete surface and all relevant states rather than changing only the element called out. Keep presentation separate from data and actions where the existing controller/component boundary provides that separation.

## Review before finishing

Compare the result with Kcast's corresponding surface and review the full interaction:

1. Check hierarchy, typography, spacing, card/row geometry, and semantic color use.
2. Check selection while hovering another item, focus, disabled and busy states, and error feedback.
3. Navigate and activate with the keyboard; check Escape, nested/back behavior, and pointer operation.
4. Check scroll bounds, popup layering, and the intended display size/scale when a live rendering is available.
5. Confirm kmDot retains ownership of lifecycle, theme data, and domain behavior.
