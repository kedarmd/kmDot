# Arch package-availability delta for every install.sh entry

Research for `kedarmd/kmDot#95` (map #94). Question: for every package named in
`install.sh` PKGS, is it in Arch official repos, in AUR (under what name), or
unavailable — and does the `install_pkg` pacman-first/yay-fallback logic resolve
each correctly on stock Arch with no CachyOS repos?

Method: queried primary sources 2026-10-03 — Arch official JSON search API
(`https://archlinux.org/packages/search/json/?q=<name>`, exact-name match, repo +
version recorded) and AUR RPC v5 (`type=info` for exact hits, `type=search` for
variant survey). Pure Arch + AUR only; CachyOS repos out of scope per the map.
Versions are snapshot-at-research-time; names/repos are the durable finding.

## Verdict up front

- **34 of 36 named packages are in Arch official `extra`** under the exact name
  `install.sh` already uses. No rename needed for any of them.
- **2 packages are AUR-only**: `herdr-bin` and `zen-browser`, both under the exact
  name `install.sh` already uses. `install_pkg` resolves them via the yay
  fallback. No rename needed, but see the two flags below.
- **Flag 1 (build cost): `zen-browser` (source) vs `zen-browser-bin`.** The name
  in `install.sh` is the AUR *source* build ("built from upstream release source
  snapshot", 50 votes, at 1.21.15b at research time) while `zen-browser-bin`
  (prebuilt binary, 341 votes, at 1.22.3b) is the popular, fast, fresher pick.
  Resolution is correct (yay finds `zen-browser`), but a source build of a
  Firefox fork on a minimal guest means a long compile — the VM-proof / baseline
  tickets should budget for it or consider switching to `-bin`.
- **Flag 2 (stale assumption, good news): `quickshell` is in official `extra`
  (0.3.1).** The AGENTS.md note that quickshell comes from `cachyos-extra-v4`
  is a CachyOS-only statement; stock Arch needs no extra repo for it. Same
  applies to every other prime suspect: `ghostty` (1.3.1), `hyprshot` (1.3.0),
  `awww` (0.12.1) are all official `extra` now.
- **`install_pkg` logic verdict: correct for every entry.** The
  `pacman -Si "$pkg"` gate routes all 34 official packages to pacman and the 2
  AUR-only names to yay. One standing caveat (provisioning, not naming):
  `pacman -Si` only sees a package after a DB sync, so a minimal guest still
  needs working mirrors + `pacman -Sy` before `--all` — that belongs to the
  baseline/provisioning ticket, not this one.

## Per-package table

| package (as in install.sh) | Arch official? | AUR name? | verdict / notes |
|---|---|---|---|
| fish | yes, extra 4.9.3 | n/a (official) | pacman path. OK |
| ghostty | yes, extra 1.3.1 | n/a (official) | prime suspect CLEARED — official, no AUR needed |
| herdr-bin | no | yes, `herdr-bin` 0.9.3-1 (maintained, 14 votes) | prime suspect verdict: AUR-only under exact name; yay fallback resolves it. `-bin` choice is the fast one (source `herdr` also exists, 3 votes — correctly NOT used). OK |
| hyprland | yes, extra 0.56.2 | — | pacman path. OK |
| hypridle | yes, extra 0.1.8 | — | pacman path. OK |
| hyprlock | yes, extra 0.9.6 | — | pacman path. OK |
| hyprshot | yes, extra 1.3.0 | — | prime suspect CLEARED — official |
| awww | yes, extra 0.12.1 | — | prime suspect CLEARED — official |
| neovim | yes, extra 0.12.5 | — | pacman path. OK |
| quickshell | yes, extra 0.3.1 | — | prime suspect CLEARED — official `extra`, no cachyos-extra-v4 needed on stock Arch |
| sddm | yes, extra 0.21.0 | — | pacman path. OK (enabling the DM on a minimal guest is provisioning-ticket scope) |
| starship | yes, extra 1.26.0 | — | pacman path. OK |
| tmux | yes, extra 3.7_c | — | pacman path. OK |
| xdg-desktop-portal | yes, extra 1.22.1 | — | pacman path. OK |
| xdg-desktop-portal-hyprland | yes, extra 1.4.1 | — | pacman path. OK |
| ttf-jetbrains-mono-nerd | yes, extra 3.5.1 | — | pacman path. OK |
| networkmanager | yes, extra 1.58.1 | — | pacman path. OK |
| network-manager-applet | yes, extra 1.36.0 | — | pacman path. OK |
| pipewire | yes, extra | — | pacman path. OK |
| wireplumber | yes, extra 0.5.18 | — | pacman path. OK |
| pipewire-pulse | yes, extra 1.6.9 | — | pacman path. OK |
| bluez | yes, extra 5.87 | — | pacman path. OK |
| blueman | yes, extra 2.4.6 | — | pacman path. OK (kept solely as BlueZ pairing agent per AGENTS.md) |
| wl-clipboard | yes, extra 2.3.0 | — | pacman path. OK |
| brightnessctl | yes, extra 0.5.1 | — | pacman path. OK |
| upower | yes, extra 1.91.4 | — | pacman path. OK |
| jq | yes, extra 1.8.2 | — | pacman path. OK |
| playerctl | yes, extra 2.4.1 | — | pacman path. OK |
| curl | yes, official | — | pacman path (also a no-AUR-installer dependency). OK |
| libnotify | yes, extra 0.8.8 | — | pacman path. OK |
| power-profiles-daemon | yes, extra 0.30 | — | pacman path. OK |
| lua | yes, extra 5.5.1 | — | pacman path. OK |
| gnome-keyring | yes, extra 50.0 | — | pacman path. OK |
| nautilus | yes, extra 50.3.1 | — | pacman path. OK |
| zen-browser | no | yes, `zen-browser` 1.21.15b-1 (source build, 50 votes) | prime suspect verdict: AUR-only under exact name; yay fallback resolves it — BUT consider `zen-browser-bin` (prebuilt, 341 votes, 1.22.3b, fresher). Source build = heavy compile on minimal guest. Flag for baseline/proof tickets |
| btop (themed-extras) | yes, extra 1.4.7 | — | pacman path. OK |
| tailscale (server) | yes, extra 1.102.4 | — | pacman path. OK |
| jellyfin-server (server) | yes, extra 12.1 | — | pacman path. OK |
| docker (server) | yes, extra 29.8.2 | — | pacman path. OK (service enablement is provisioning scope) |
| containerd (server) | yes, extra 2.4.1 | — | pacman path. OK |
| gtk-layer-shell (handy dep) | yes, extra 0.10.1 | — | pacman path via `install_pkg`. OK |
| fuse2 (handy dep) | yes, extra 2.9.9 | — | pacman path via `install_pkg`. OK |
| gum (bootstrap) | yes, extra 2.0.2 | — | direct `sudo pacman -S gum` (no yay fallback) is SAFE — official. OK |
| git (bootstrap) | yes, extra | — | direct pacman. OK |
| base-devel (bootstrap) | yes, group | — | direct pacman group install. OK |
| yay (bootstrap) | no | yes, `yay` 13.0.1-1 | AUR-only as expected; bootstrapped via git clone + makepkg, no pacman involvement. OK |
| mise (bootstrap) | yes, extra (also curl-pipe in script) | — | script uses upstream curl pipe (distro-agnostic); official `mise` exists as an alternative. OK either way |
| opencode (npm, no-AUR) | n/a (npm `opencode-ai@1.18.34` via mise Node) | — | distro-agnostic. No Arch delta |
| zed (official script, no-AUR) | n/a (zed.dev/install.sh, hash-pinned) | — | distro-agnostic. No Arch delta |
| handy (AppImage, no-AUR) | n/a (upstream AppImage, hash-pinned; deps fuse2 + gtk-layer-shell official, see above) | AUR `handy-bin` exists but script warns-and-skips on conflict by design | distro-agnostic. No Arch delta |

## Handoff to map tickets

1. `zen-browser` source-vs-bin choice (build-time cost on minimal guest) — for the baseline/proof-scope decision.
2. Minimal-guest DB sync + mirror setup before `--all` (`pacman -Si` gate needs a synced DB) — provisioning ticket.
3. Service enablement (sddm/docker/etc.) on a display-manager-less minimal install — provisioning ticket (naming is all-clear here).
