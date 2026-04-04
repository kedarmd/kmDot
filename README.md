# kmDot

Dotfiles for a CachyOS + Hyprland workstation. This repo is the source of truth and ships a sync model that copies config into `~/.config/kmdot` and then symlinks to app config locations.

## Supported Apps

- fish
- ghostty
- hyprland
- nvim
- rofi
- starship
- waybar
- theme-switcher
- tmux
- xdg-desktop-portal

## Install (CachyOS / pacman)

```bash
sudo pacman -S gum tmux git jq hyprpaper waybar rofi starship ghostty fish
```

Run the installer and select apps:

```bash
./install.sh
```

## Sync Model

- Repo config lives in `config/`, `themes/`, and `theme-switcher/`.
- Sync scripts in `sync/` copy configs into `~/.config/kmdot/`.
- Symlinks are created from `~/.config/` (and `~/.tmux.conf`) to `~/.config/kmdot/`.
- Do not edit `~/.config/*` directly.

## Theme Switching

Themes live in `themes/<theme>/`.

```bash
~/.config/kmdot/theme-switcher/main.sh <theme>
```

Available themes:

- catppuccin
- everforest
- nord
- onedark
- tokyonight

## Tmux

- Prefix: `C-s`
- Config: `config/tmux/conf.d/`
- Theme colors: `themes/<theme>/tmux.conf`
- Reload: `C-s` then `r`

TPM setup:

```bash
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
```

## Troubleshooting

### Nerd Font glyphs not rendering in tmux

Ensure UTF-8 locale is set and exported:

```bash
echo $LANG
locale
```

Recommended:

```bash
LANG=en_IN.UTF-8
LC_ALL=en_IN.UTF-8
```

### hyprpaper errors on theme switch

The wallpaper script exits early if hyprpaper is not running. Start hyprpaper before switching themes.
