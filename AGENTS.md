# AGENTS.md

Dotfiles for a CachyOS + Hyprland workstation. Config files (not application code) — no build, no tests, no CI.

## Sync Model (Required)

- **Source of truth** is this repo: `config/`, `theme-switcher/`, `themes/`, `sync/`.
- **Never write directly** to `~/.config/*` or `~/.tmux.conf`. Edit the repo, then run `sync/<app>.sh`.
- Sync scripts (e.g. `sync/tmux.sh`) `rm -rf` existing config, `cp -r` from repo, then `ln -sf` to standard locations. Destructive.

## Runtime Requirements

- **No Python or other interpreted languages.** This repo is deployed across all devices; Python is NOT guaranteed to be installed. Scripts must be bash (`#!/usr/bin/env bash`) or **JavaScript (Node) — the only exception** (Node is installed everywhere, e.g. `calendar-events.mjs`, the `toggle.sh` socket connect). Prefer bash whenever it can express the task; use Node only when bash can't. Never add `.py`/`.rb`/`.pl`/etc. — the old `server-mode-watcher.py` and the `python3` socket connect in `toggle.sh` were both removed for this reason. Prefer config-only solutions over code where possible.
- **Scripts must be executable.** Files written by an editor default to 0644, which breaks anything that spawns a script by path (a script run under `systemd-inhibit` once exited `status=1/FAILURE` because it wasn't `+x` — no sleep lock AND no screen dim). `sync/quickshell.sh` runs `chmod +x scripts/*.sh` as a safety net; if you create a new script, `chmod +x` it in the repo.

## Commands

| Action | Command | Notes |
|---|---|---|
| Install selected apps | `./config-install.sh` | Requires `gum` (`pacman -S gum`). Multi-select TUI. |
| Install packages | `./install.sh` | Installs official Arch repository packages and approved upstream releases. Never uses AUR. Gum TUI + `--all` flag. |
| Single-app sync | `./sync/<app>.sh` | E.g. `./sync/nvim.sh`. Skips the TUI picker. |
| Uninstall | `./config-uninstall.sh` | Also requires `gum`. Removes symlink targets + kmdot copies. |
| Switch theme (CLI) | `theme-switcher/main.sh <theme>` | Themes: catppuccin, everforest, nord, tokyonight |
| Switch theme (quickshell launcher) | `config/quickshell/scripts/toggle.sh kmdot-theme` (Super+T) | Picks theme via quickshell launcher, calls `main.sh` (which restarts quickshell once) |
| Quickshell sync | `./sync/quickshell.sh` | Bar config lives in `config/quickshell/`. |
| Server mode (icon in hidden tray, right group) | hover the chevron (before Wi-Fi), click the server icon | Toggles the headless-server mode (see Key Quirks). |
| Install polkit rule (one-time, sudo) | `sudo install -Dm644 config/polkit/90-kmdot-server-mode.rules /etc/polkit-1/rules.d/` | Lets the bar start/stop tailscaled/jellyfin/docker/containerd without password prompts. |

## Arch package source policy (strict)

- Install system packages only from the official Arch Linux repositories with `pacman`.
- **Never install or recommend AUR packages. Never install, bootstrap, or invoke an AUR helper** such as `yay` or `paru`. Apply this to interactive installs, `--all`, dependencies, fallbacks, and test setup.
- If an application is not available in the official repositories, use its official upstream installer, release binary, AppImage, or npm package with a pinned version where practical. Do not silently fall back to AUR.
- Keep installer changes and runbooks consistent with this rule. AUR/foreign package checks in the fresh Arch smoke test must continue to pass.

For sync activation, app removal, or a desktop crash, see [Config lifecycle](docs/agents/config-lifecycle.md).

## Adding an App

1. Create `config/<app>/` with config files.
2. Create `sync/<app>.sh` (copy + symlink pattern — see existing scripts).
3. Add to `APPS` array in `config-install.sh` (and `config-uninstall.sh` if supported).

## Adding a Theme

1. Create `themes/<theme>/` with per-app config files matching each hook in `theme-switcher/hooks/`.
2. Theme hooks read from `~/.config/kmdot/themes/<theme>/`, not the repo directly.
3. Theme hooks reload the app after writing the config (e.g. `tmux source-file`).

## Quickshell theme colors

When changing a palette, adding a semantic color role, or changing a component's role assignment, read [the theme audit](docs/quickshell-theme-audit.md) for upstream sources, role mappings, and validation coverage.

Every theme explicitly defines the complete schema in `theme-switcher/quickshell.roles`. `render-quickshell.sh` validates it before deployment or preview. `Colors.qml` is generated during sync; it has no repository default. Sync takes the saved theme selection or an explicit theme argument. Use upstream role definitions and documented UI precedents; record desktop adaptations when upstream does not specify a role. Store derived upstream values in the theme file. Keep `Tokens.qml` as semantic aliases; preserve each role's explicit foreground/background pair.

## Quickshell visual design

When creating, restyling, or reviewing a Quickshell launcher, popup, dropdown, or control, read [the Quickshell design language](docs/quickshell-design-language.md). It records the oma-cast reference and approved kmDot adaptations for geometry, control states, menu behavior, affordances, and visual review.

## Operational reference

When working on Quickshell, themes, wallpapers, audio, server mode, or other workstation integrations, read [the detailed operational quirks](docs/agents/key-quirks.md) for the relevant area. It records runtime behavior and non-obvious constraints that are easy to break.

## Agent skills

### Issue tracker

Issues are tracked on GitHub (`kedarmd/kmDot`) via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Five canonical triage roles kept under their default names (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `CONTEXT.md` + `docs/adr/` at the repo root. See `docs/agents/domain.md`.

### Quickshell UI skill

For Quickshell UI implementation or review in this repository, use [the kmDot Quickshell UI skill](.agents/skills/kmdot-quickshell-ui/SKILL.md). It treats the embedded Kcast launcher as the visual and interaction reference while preserving kmDot's integration boundaries.
