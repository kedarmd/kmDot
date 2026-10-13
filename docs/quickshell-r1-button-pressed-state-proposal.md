# Quickshell R1 button pressed state proposal

Revision: 1
Status: Approved by the user and applied on 2026-10-13; awaiting final design review
Target: Redesign → Foundations — R1 → `button/pressed`

## Problem

The R1 button examples label separate hover and pressed states, but both
initially used the same fill, `#3B4261`. The Foundations caption instead said
they use 8% and 12% overlays. Live component data confirms there are no such
overlays. The rendered states therefore look identical despite having
different names.

## Proposed change

- Keep hover at TokyoNight `#3B4261` (`night.outline`).
- Change the existing pressed component fill to TokyoNight `#283457`
  (`night.selected` / `primary_container`), retaining the current light label.
- Keep the 2px TokyoNight primary focus ring and 38% disabled opacity as they
  are.
- Replace the inaccurate overlay caption with the actual hover, pressed,
  focus, and disabled treatment.

This creates a visible pressed state using an existing canonical TokyoNight
swatch. It adds no token, component, variant, spacing, or typography value.
The proposed foreground/background pair remains high contrast; the existing
R1 contrast notes report 7.57:1 for light text on the selected surface.

## Exact target

- Component: `button/pressed`
- Component ID: `cfe1987a-fff1-803d-8008-c759af2f3416`
- Main shape ID: `cfe1987a-fff1-803d-8008-c759aeb46b42`
- Current fill: `#3B4261`
- Proposed fill: `#283457`

## Applied result

The user approved Revision 1. The `button/pressed` component now uses
`#283457` with the `night.selected` token; hover remains `#3B4261`. The
Foundations caption now reads: `Focus ring 2px · Hover #3B4261 · Pressed
#283457 · Disabled opacity 38%`. The pressed button export confirms the new
selected-surface fill and light label. Final R1 design review is pending.
