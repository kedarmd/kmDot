# Quickshell Design Status

Design work is in FigCraft. No production QML has been written.

## Design system

**Status:** Ready for review. The proposal remains unapproved. The user requested a sized top-bar exploration to judge the system visually; this does not mark the design system approved or authorize production QML.

**FigCraft reference:** Current in-memory FigCraft document, page `00 · Foundations` (four theme specimens) and page `01 · Components & rules` (tokens, component contracts, type, spacing, states, and motion). FigCraft MCP currently rejects all save paths, so the document has no persistent file reference. This remains an unresolved workflow issue.

| Foundation | Tokyo Night Storm | Catppuccin Macchiato | Everforest dark medium | Nord dark |
|---|---|---|---|---|
| Semantic color and component foundation | Ready for review | Ready for review | Ready for review | Ready for review |

**Current design proposal:** 20 shared semantic color roles; four mode recommendations from `THEME_RESEARCH.md`; Inter UI typography with JetBrains Mono for numeric telemetry; 4/8/12/16/24/32/48 spacing; 8/14/22 corner radii; workspace navigator, utility module, status chip, and anchored panel contracts; explicit focus, selected, busy, disabled, empty, and error cues. Status foreground roles are explicit per status. Nord's error fill is a darker desktop adaptation so its on-error text reaches the contrast target.

**Validation:** Candidate primary, secondary, and disabled text pairs were checked against canvas, surface, raised, and sunken roles at WCAG AA 4.5:1; focus indicators were checked against those surfaces at 3:1; filled accent and status pairs were checked for readable foregrounds. Minimum measured ratios were 4.53:1 (text), 4.31:1 (focus), 4.64:1 (on-accent), and 4.64:1 (status foregrounds). These checks cover the candidate solid colors before opacity or compositing; they do not validate later screen-specific use or animation.

## Feature designs

Each cell tracks that feature and theme independently.

| Feature | Tokyo Night Storm | Catppuccin Macchiato | Everforest dark medium | Nord dark |
|---|---|---|---|---|
| QS-01 Per-monitor desktop bar and workspaces | Ready for review | Ready for review | Ready for review | Ready for review |
| QS-02 Application launcher | Not started | Not started | Not started | Not started |
| QS-03 kmDot command launcher and nested navigation | Not started | Not started | Not started | Not started |
| QS-04 System actions | Not started | Not started | Not started | Not started |
| QS-05 Theme selection and theme-switcher integration | Not started | Not started | Not started | Not started |
| QS-06 Wallpaper selection | Not started | Not started | Not started | Not started |
| QS-07 Clipboard history | Not started | Not started | Not started | Not started |
| QS-08 Wi-Fi management surfaces | Not started | Not started | Not started | Not started |
| QS-09 Bluetooth management surfaces | Not started | Not started | Not started | Not started |
| QS-10 Audio output/input controls and media status | Not started | Not started | Not started | Not started |
| QS-11 Battery information and power profiles | Not started | Not started | Not started | Not started |
| QS-12 Display arrangement, monitor modes, and brightness | Not started | Not started | Not started | Not started |
| QS-13 Calendar and agenda | Not started | Not started | Not started | Not started |
| QS-14 Notifications, notification center, and replies | Not started | Not started | Not started | Not started |
| QS-15 Volume, brightness, and microphone OSDs | Not started | Not started | Not started | Not started |
| QS-16 Native session lock screen | Not started | Not started | Not started | Not started |
| QS-17 Server mode and service control | Not started | Not started | Not started | Not started |
| QS-18 Attention mode and idle behavior | Not started | Not started | Not started | Not started |
| QS-19 Handy transcription controls and history | Not started | Not started | Not started | Not started |
| QS-20 OpenCode and AI-agent usage panels | Not started | Not started | Not started | Not started |
| QS-21 Display keybind reference | Not started | Not started | Not started | Not started |

**QS-01 initial FigCraft references:** pages `02 · Tokyo Night · Top bar`, `03 · Catppuccin · Top bar`, `04 · Everforest · Top bar`, and `05 · Nord · Top bar` in the current in-memory document. These are retained as the first proposal, now superseded for review by the icon-led exploration below. Page references are not durable because FigCraft cannot save to disk at present.

**QS-01 icon-led exploration, revision 3:** two alternatives, each shown in all four theme modes. Direction A, `Glyph Rail`, uses an unboxed workspace glyph rail, centered time, terse icon-and-value status groups, and a single ruled control sheet. Direction B, `Ambient Console`, uses the same icon-led navigation with larger telemetry and a two-column status sheet without individual cards. Both use a 56 px bar with 24 px glyphs and preserve 40 px module hit areas. The expanded sheet is explicitly a menu: each row has a trailing chevron and opens its own feature panel. Server Mode summarizes its current state and opens the dedicated service controls; AI Usage summarizes the detected OpenCode/Codex/Pi providers over seven days and opens the provider breakdown. The detail panels remain in their later feature-design stages. Both directions use the existing semantic tokens and component contracts; this revision adds no reusable components or color tokens. All eight variants are ready for review, not approved.

**QS-01 feedback revision:** The four `Ambient Console` open sheets now use the existing 18 px surface-radius token, matching the rounded treatment already used by `Glyph Rail`. No new radius token was introduced.

**Icon-language proposal:** FigCraft page `14 · Icon language proposal` presents a custom 24 px outline family in all four theme treatments: speaker with sound waves, sun/rays, Wi-Fi connected and disconnected, battery with charging bolt, and focus inactive/active. The proposal uses a consistent 2 px line and communicates active states with the theme accent. In response to feedback, focus was changed from corner brackets to a target: the inactive state has a slash and the active state has a precise center point. The liked speaker, sun, Wi-Fi, and charging symbols are carried into the current QS-01 screen proposal; focus remains a review candidate.

**QS-01 screen revision:** FigCraft pages `15 · Rounded Rail · Tokyo Night`, `16 · Rounded Rail · Catppuccin`, `17 · Rounded Rail · Everforest`, and `18 · Rounded Rail · Nord` now use the approved outline icon family and the 18 px rounded panel surface. The persistent module order is Sound, Wi-Fi, Bluetooth, Battery, Displays, Notifications. Brightness is absent from the top bar and belongs in the Displays panel; battery shows percentage and charging state. The expanded More menu has four spacious rows in the order Handy, Focus Mode, Coding Agents, Server Mode. Its current specimen shows Focus off and Server Mode off. Notifications, Bluetooth, Displays, and Wi-Fi are absent from More. Each theme variant is ready for review and remains independently unapproved.

**Latest QS-01 feedback:** The user clarified that the required feature placement matters more than their initial ordering and invited a more suitable sequence. The current proposal orders persistent controls by glance/use frequency and groups connectivity: Sound, Wi-Fi, Bluetooth, Battery, Displays, Notifications. More is ordered as Handy, Focus Mode, Coding Agents, Server Mode: quick personal actions first, then usage/status views, with the system-level server toggle last. More contains only those four features. Displays, Bluetooth, and Wi-Fi remain dedicated top-bar entries and are excluded from More. Displays owns the dedicated brightness slider; there is no brightness value or slider in the top bar. Battery shows percentage and an explicit charging/discharging state.

**Icon-system decision:** The user approved FigCraft page `19 · Control icon system`'s 24 px outline family. Its four theme treatments cover Sound, Wi-Fi, Bluetooth, Battery (charging/discharging states), Displays, Notifications, Handy, Focus Mode, Coding Agents, and Server Mode. Focus off and on states are both shown in the specimen. The same family is now applied to the four QS-01 screen variants.

**QS-01 revision 3 FigCraft references:** `06 · Glyph Rail · Tokyo Night`, `08 · Glyph Rail · Catppuccin`, `09 · Glyph Rail · Everforest`, `10 · Glyph Rail · Nord`, `07 · Ambient Console · Tokyo Night`, `11 · Ambient Console · Catppuccin`, `12 · Ambient Console · Everforest`, and `13 · Ambient Console · Nord`.

**QS-01 interaction coverage:** workspaces 01–04 with 01 active; expanded More control with Handy, Focus Mode, Coding Agents, and Server Mode rows, each showing a state summary and panel chevron; visible Sound, Wi-Fi, Bluetooth, Battery, Displays, Notifications, and clock/calendar entry points. Dedicated popup behavior and additional Focus/Server states remain in their later feature designs.

## Open items

- FigCraft MCP has no writable path configured, which prevents saving the design source. The board remains in the current live session only.
- Once QS-01 is approved, continue with the next feature in dependency order. Include the dedicated brightness slider in the QS-12 Displays panel design.
- Contrast values are candidates; verify the actual theme-file values and final rendered foreground/background combinations when each feature is designed.
- Record a durable FigCraft document reference once saving is enabled.
