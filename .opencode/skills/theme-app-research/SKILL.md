---
name: theme-app-research
description: Background research skill for kmDot app integrations — investigate against primary sources either how to install an application on CachyOS/Arch (goal install-methods) or how the application's theming works, config locations, formats, and reload behavior (goal theming-internals). Returns structured findings to the calling agent; writes nothing.
---

# Research for kmDot App Integration

You are a read-only researcher. Investigate against **primary sources only**: official documentation, upstream source code, archlinux.org/packages, aur.archlinux.org, first-party APIs. A secondary write-up is a lead, never a citation. Cite a URL next to every load-bearing claim. State uncertainty plainly rather than smoothing it over — a wrong fact here becomes a wrong theme file later.

Return findings in your final message using the templates below. Modify nothing.

## Goal: install-methods

How to get the app running on CachyOS (Arch-based). Priority order: official pacman repos → AUR → flatpak → upstream binary/package. Cover:

1. Binary name(s) after install (may differ from the app's marketing name).
2. Package name(s) per source, with the exact command (`sudo pacman -S …`, `<aur-helper> -S …`, `flatpak install …`).
3. Post-install requirements: groups, services, autostart, first-run steps.
4. Which single source you recommend and why.

Return as:

```
binary: <name>
recommended: <source + command>
alternatives: <source + command, ...>
post-install: <steps or "none">
sources: <urls>
confidence: high|medium|low + why
```

## Goal: theming-internals

How the app's colors/themes are driven. Determine:

1. **Mechanism classification** — pick one:
   - *pointer*: the app ships native themes kmDot can reference by name (ghostty `theme =`, btop `color_theme =`, zed `"theme":`). Identify where those native themes come from (built-in registry, extension marketplace, downloadable files) and whether installing them is a separate step.
   - *raw-config*: colors are written into the app's own config in its native syntax (swaync.css, quickshell.conf).
   - *none / hybrid* — explain.
2. **Exact config path(s)** under `$HOME` — the real XDG location, which may differ from the app name (hypr → hyprland). Note any non-XDG or root-owned paths.
3. **File format and syntax** — with a minimal sample snippet showing the keys that carry colors/theme names.
4. **Reload semantics** — hot-reload on config change? Needs restart (exact restart command)? Reads config only at launch?
5. **Canonical palettes** — upstream sources for our five themes (tokyonight=folke/tokyonight.nvim night · catppuccin=mocha · everforest=dark hard · nord=nordtheme.com · onedark=atom/one-dark-syntax), specifically where this app can consume them.
6. **Gotchas** — atomic-write needs (file watchers), comments stripped, generated files overwritten on exit, etc.

Return as:

```
mechanism: pointer|raw-config|none|hybrid + one-line explanation
native-themes-source: <where pointer themes come from, or n/a>
config-paths: <exact absolute path(s), noting dir vs file>
format: <toml|css|json|jsonc|ini|conf ...> + sample snippet
reload: hot-reload | restart(<command>) | launch-only
canonical-palette-pointers: <urls/repo paths per theme>
gotchas: <list or "none found">
sources: <urls>
confidence: high|medium|low + why
```

If both goals run in one session, return both blocks under clear headings.
