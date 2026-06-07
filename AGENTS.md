# AGENTS.md

Dotfiles for a CachyOS + Hyprland workstation. Config files (not application code) — no build, no tests, no CI.

## Sync Model (Required)

- **Source of truth** is this repo: `config/`, `theme-switcher/`, `themes/`, `sync/`.
- **Never write directly** to `~/.config/*` or `~/.tmux.conf`. Edit the repo, then run `sync/<app>.sh`.
- Sync scripts (e.g. `sync/tmux.sh`) `rm -rf` existing config, `cp -r` from repo, then `ln -sf` to standard locations. Destructive.

## Commands

| Action | Command | Notes |
|---|---|---|
| Install selected apps | `./install.sh` | Requires `gum` (`pacman -S gum`). Multi-select TUI. |
| Single-app sync | `./sync/<app>.sh` | E.g. `./sync/nvim.sh`. Skips the TUI picker. |
| Uninstall | `./uninstall.sh` | Also requires `gum`. Removes symlink targets + kmdot copies. |
| Switch theme (CLI) | `theme-switcher/main.sh <theme>` | Themes: catppuccin, everforest, nord, onedark, tokyonight |
| Switch theme (rofi) | `config/rofi/menu/theme-switcher.sh` (via rofi launcher after sync) | Picks theme via rofi dmenu, calls main.sh |

## Adding an App

1. Create `config/<app>/` with config files.
2. Create `sync/<app>.sh` (copy + symlink pattern — see existing scripts).
3. Add to `APPS` array in `install.sh` (and `uninstall.sh` if supported).

## Adding a Theme

1. Create `themes/<theme>/` with per-app config files matching each hook in `theme-switcher/hooks/`.
2. Theme hooks read from `~/.config/kmdot/themes/<theme>/`, not the repo directly.
3. Theme hooks reload the app after writing the config (e.g. `pkill waybar && waybar`, `tmux source-file`).

## Key Quirks

- **Tmux**: prefix `C-s`; modular config in `config/tmux/conf.d/` (`00-base`, `10-bindings`, `20-theme`, `90-plugins`); TPM for plugins; UTF-8 locale required for Nerd Fonts.
- **Neovim**: lazy.nvim plugin manager; entrypoint `init.lua` → `require("options")` + `require("config.lazy")`.
- **Wallpapers**: theme-specific in `themes/<theme>/wallpapers/`; `cycle_wallpapers.sh` exits early if hyprpaper isn't running; active theme cached in `~/.cache/kmdot_theme`.
- **Gitignored**: `hyprland.conf.backup`, `config/fish/secrets.fish`.
- **OpenCode theme hook**: writes to `~/.config/opencode/tui.json` via `theme-switcher/hooks/opencode.sh`.
