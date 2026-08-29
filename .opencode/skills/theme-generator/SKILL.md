---
name: theme-generator
description: Generate kmDot per-theme files for one application — themes/{catppuccin,everforest,nord,onedark,tokyonight}/<app>.<ext> — choosing pointer-style or full-config-style from research findings and using each theme's canonical palette. Runs in build mode (writes the files) or plan mode (returns full contents, writes nothing). Used by the add-themed-app orchestrator.
---

# Generate Theme Files

Produce one theme file per kmDot theme for a single application. Inputs arrive in the dispatch prompt: app name, research findings (from `theme-app-research`), and mode (`build` or `plan`).

## 1. Pick the archetype

Match the research's mechanism classification to the closest existing exemplar — copy its shape, never invent a parallel convention:

| Mechanism | Exemplars | Shape |
| --- | --- | --- |
| pointer | `themes/tokyonight/ghostty.conf` (`theme = "TokyoNight Night"`), `btop.conf`, `zed.conf`, `opencode.conf` | One line naming the app's native theme for our palette |
| raw-config | `themes/tokyonight/quickshell.conf`, `hyprland.lua`, `nvim.lua`, `tmux.conf`, `starship.toml` | Full color config in the app's native syntax |

Read the exemplar in all five theme dirs before writing anything — per-theme file conventions (headers, comment style) live in the files themselves.

Done when: archetype chosen and exemplars read.

## 2. Decide the file name

`themes/<theme>/<app>.<ext>`: lowercase app name, `<ext>` is the format the app consumes (`.conf` by convention for pointer files regardless of the app's native format; native extensions like `.css`/`.toml`/`.lua` for raw-config). The name must match what the hook will read — coordinate via the dispatch findings' `config-paths`.

Pointer-style requires the app's own theme names to exist for our palettes; if research shows they don't, fall back to raw-config style using canonical hex values.

## 3. Use canonical palettes only

Every color traces to the theme's real swatch source:

| Theme | Canonical source |
| --- | --- |
| tokyonight | folke/tokyonight.nvim (night) |
| catppuccin | catppuccin/catppuccin (mocha) |
| everforest | sainnhe/everforest (dark hard) |
| nord | nordtheme.com |
| onedark | atom/one-dark-syntax |

For pointer style this means the correct native theme NAME per theme (e.g. ghostty ships `TokyoNight Night`, `catppuccin-mocha`, `Everforest Dark - Hard`, `Nord`, `One Dark`). For raw-config it means hex values pulled from those sources — fetch them from the upstream repo/files rather than recalling. Contrast rule of thumb from AGENTS.md: active/selected surfaces are dark tonal containers with light text.

Done when: every emitted value maps to a cited canonical source.

## 4. Emit

**Build mode** — write `themes/<theme>/<app>.<ext>` for all five themes, matching each theme dir's existing header/comment conventions. If files already exist, update them in place (idempotent) rather than duplicating.

**Plan mode** — return, per theme, the complete file contents in fenced blocks with the target path above each block, plus a short rationale (archetype choice + palette provenance). Write nothing.

Done when: five files written, or five complete fenced blocks returned.
