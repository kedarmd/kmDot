# Quickshell Theme Research

Phase 3 research for the kmDot Quickshell redesign. This document uses the theme projects' first-party palette documentation and repositories. It does not draw on previous kmDot palettes or visuals. Palette values below are upstream reference values; semantic mappings and variant choices are recommendations for later design and remain subject to design approval.

## Shared semantic contract

The four themes should supply the same semantic roles so component behavior remains consistent while their color identities remain distinct. These are role names, not prescribed colors:

| Role | Intended use |
|---|---|
| `canvas` | Primary desktop and overlay backdrop |
| `surface` | Main cards, panels, and popup bodies |
| `surfaceRaised` | Menus, nested cards, selected rows, and elevated controls |
| `surfaceSunken` | Input fields, tracks, and recessed regions |
| `textPrimary` | Main readable content |
| `textSecondary` | Supporting labels and metadata |
| `textDisabled` | Unavailable actions and inactive metadata |
| `border` | Structural boundaries and separators |
| `focus` | Keyboard focus indicator |
| `accentPrimary` | Main action, active navigation, and selection |
| `accentSecondary` | Secondary emphasis and supporting selected states |
| `success`, `warning`, `error`, `info` | Status meaning and feedback |
| `onAccent` | Foreground paired with primary accent fills |
| `onStatus` | Foreground paired with status fills |

**Recommendation:** provide explicit foreground/background pairs for filled accents and status colors. Do not assume that a theme's named accent can be used as text on every surface. Derive or choose each pair and measure it. Keep decorative accents separate from semantic status roles so a green brand accent does not automatically mean “successful.”

### Accessibility and state guidance

- Target WCAG 2.2 AA text contrast: at least **4.5:1** for ordinary text and **3:1** for large text. Measure each rendered foreground against its actual adjacent background, including text on selected rows, chips, and buttons. The W3C defines large text as at least 18 pt regular or 14 pt bold. [WCAG 2.2 SC 1.4.3](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html)
- Meaningful control boundaries, selected/focused states, and graphical indicators should reach **3:1** against adjacent colors where WCAG 2.2 SC 1.4.11 applies. [WCAG 2.2 SC 1.4.11](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html)
- These are acceptance targets for the eventual UI, not claims that every upstream palette pair already passes. Pastel or dim theme accents may require a separate text-safe token or a different foreground/background pairing. Re-check after opacity, blur, compositing, or animation is applied.
- Do not communicate enabled, selected, warning, error, or focus state by hue alone. Combine color with shape, position, iconography, text, or an explicit indicator. Keyboard focus must remain visible and distinguishable from hover and selection.
- Disabled content may be visually quieter, but preserve legibility for content users still need to understand. Prefer behavior and affordance cues in addition to dimming.

## Tokyo Night

**Upstream facts.** The official Tokyo Night VS Code project describes a dark theme inspired by downtown Tokyo at night. It publishes Tokyo Night, Tokyo Night Storm, and Tokyo Night Light variants. Its README says many UI elements are intentionally low contrast, and lists the shared night/storm syntax colors: blue `#7aa2f7`, purple `#bb9af7`, cyan `#7dcfff`, teal `#73daca`, green `#9ece6a`, yellow `#e0af68`, orange `#ff9e64`, red `#f7768e`, and foreground `#c0caf5`. The README identifies Night editor background `#1a1b26` and Storm editor background `#24283b`; Light uses `#e6e7ed`. These are upstream theme values and syntax/UI references, not validated semantic accessibility pairs. [Official repository and palette](https://github.com/tokyo-night/tokyo-night-vscode-theme)

**Available variants:** Night (dark), Storm (dark with a lighter/slate base), and Light. The first-party project presents all three; the dark variants share a large part of their accent palette.

**Recommendation — Tokyo Night Storm.** The Storm base gives the interface a distinct blue-slate foundation while preserving the Tokyo Night accent family. This is a design recommendation, not an upstream preference. A dark desktop interface is the intended context, and Storm's lighter base may help distinguish layered controls without changing all components to a light scheme. If contrast checks show text or focus issues, choose role-specific alternatives from the upstream palette or a documented desktop adaptation; do not adopt the project’s intentionally low-contrast treatment without testing.

## Catppuccin

**Upstream facts.** Catppuccin defines four named flavors: Latte (light), Frappé (dark and subdued), Macchiato (dark, described as medium contrast), and Mocha (darkest, original flavor). The palette is named by color roles such as Base, Mantle, Crust, Surface, Overlay, Text, and accent names including Rosewater, Mauve, Blue, Green, Yellow, and Red. Mocha reference values include Base `#1e1e2e`, Surface0 `#313244`, Text `#cdd6f4`, Blue `#89b4fa`, Mauve `#cba6f7`, Green `#a6e3a1`, Yellow `#f9e2af`, and Red `#f38ba8`. [Official palette](https://catppuccin.com/palette/) · [Official style guide](https://github.com/catppuccin/catppuccin/blob/main/docs/style-guide.md)

**Available variants:** Latte, Frappé, Macchiato, Mocha. The palette page explicitly characterizes Latte as light and the other three as dark.

**Recommendation — Macchiato.** Its stated medium contrast provides a sensible starting point for a desktop with many compact controls and persistent status indicators, while keeping the gentle pastel identity. This is a recommendation based on the upstream flavor descriptions; final foreground/background combinations still require WCAG checks. Mocha remains a valid option if the approved design system intentionally calls for the darkest presentation.

## Everforest

**Upstream facts.** The upstream Vim theme provides dark and light palettes. Each has hard, medium, and soft background contrast variants; medium is the documented default. Its palette reference says the listed foreground values correspond to the dark variant with default medium contrast. Example dark-medium values are background `bg0` `#2d353b`, raised `bg1` `#343f44`, foreground `#d3c6aa`, green `#a7c080`, red `#e67e80`, yellow `#dbbc7f`, aqua `#83c092`, blue `#7fbbb3`, and purple `#d699b6`. The project describes its intent as warm and soft, with a green-based scheme. [Official repository](https://github.com/sainnhe/everforest) · [Official palette reference](https://github.com/sainnhe/everforest/blob/master/palette.md) · [Variant configuration documentation](https://github.com/sainnhe/everforest/blob/master/doc/everforest.txt)

**Available variants:** dark and light palettes, each with hard, medium, and soft background contrast; medium is upstream's default. The project separately exposes UI contrast configuration, so background contrast and UI contrast should not be conflated.

**Recommendation — dark medium.** It retains Everforest's warm green identity and matches the upstream default background contrast. It provides a stable foundation for layered desktop surfaces while allowing stronger focus and selection cues to be added through semantic roles. This is a recommendation, not a claim that the default palette meets contrast targets for every role.

## Nord

**Upstream facts.** Nord describes sixteen dimmed pastel colors grouped into four named palettes: Polar Night (`nord0`–`nord3`), Snow Storm (`nord4`–`nord6`), Frost (`nord7`–`nord10`), and Aurora (`nord11`–`nord15`). It documents both dark and bright ambiance usage and describes a clean, uncluttered, minimal, flat design direction. Polar Night includes `nord0 #2e3440` through `nord3 #4c566a`; Snow Storm includes `nord4 #d8dee9` through `nord6 #eceff4`; Frost includes `nord7 #8fbcbb`, `nord8 #88c0d0`, `nord9 #81a1c1`, `nord10 #5e81ac`; Aurora includes red, orange, yellow, green, and purple accents. Nord calls `nord8` its primary accent for dark and bright use. [Official colors and palettes documentation](https://www.nordtheme.com/docs/colors-and-palettes/) · [Official project site](https://www.nordtheme.com/)

**Available variants:** Nord's canonical palette is the sixteen-color, numbered set rather than a family of named light/dark flavors. Its upstream guidance assigns palette members for dark and bright ambiance designs.

**Recommendation — dark ambiance using Polar Night surfaces, Snow Storm text, and Frost accents.** This follows Nord's own dark-use guidance and keeps the icy blue identity clear. Use Aurora colors for semantic statuses only when the role is truly a status; do not make the interface's primary identity depend on multiple competing accent hues. This mapping is a recommendation; individual text and control pairs still need measured contrast.

## Cross-theme recommendations for the design phase

1. Preserve one semantic role schema and component behavior across all four theme variants. Let each palette provide its own values for those roles.
2. Treat the recommendations above as starting variants, not final screen decisions. Review each theme separately at the same feature and state coverage; approval of one does not imply approval of another.
3. Before approval, measure the actual foreground/background pairs used for primary and secondary text, labels, icons that convey meaning, focus rings, control boundaries, selection indicators, and status chips. Record failures and adjust the external theme definitions rather than inserting theme-specific color literals into QML.
4. Use color and a second visual cue for active workspace, current network/device state, selection, warnings, errors, loading, and focus. Preserve legible distinctions for deuteranopia and grayscale viewing.
5. Keep palette values and semantic mappings external to QML. QML should consume semantic role tokens only; any desktop-specific adaptation should be recorded alongside the relevant theme definition with its contrast evidence.

## Source summary

- Tokyo Night: [official theme repository](https://github.com/tokyo-night/tokyo-night-vscode-theme)
- Catppuccin: [official palette](https://catppuccin.com/palette/) and [official style guide](https://github.com/catppuccin/catppuccin/blob/main/docs/style-guide.md)
- Everforest: [official repository](https://github.com/sainnhe/everforest), [palette reference](https://github.com/sainnhe/everforest/blob/master/palette.md), and [variant documentation](https://github.com/sainnhe/everforest/blob/master/doc/everforest.txt)
- Nord: [official palette documentation](https://www.nordtheme.com/docs/colors-and-palettes/)
- Accessibility: W3C [WCAG 2.2 text contrast](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html) and [non-text contrast](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html)
