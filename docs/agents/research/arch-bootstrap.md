# Research: Arch bootstrap and toolchain delta (map #94 / ticket #96)

Question: which CachyOS-specific bootstrap assumptions in `install.sh` break on
minimal stock Arch? Verdict per bootstrap step below, all against primary sources.
CachyOS proof is not re-derived (see `/tmp/opencode/handoff-arch-feasibility.md`).

Scope note: this ticket covers the **bootstrap/toolchain only**
(mirrors, yay, sudo/network, gum/fuse2/gtk-layer-shell, no-AUR installers).
Package-availability deltas for the main payload
(`quickshell`, `ghostty`, `zen-browser`, `herdr-bin`, `hyprshot`, `awww`, …)
belong to the sibling package-availability ticket (#95), not here.

## 0. Mirror setup replacement (the `cachyos-rate-mirrors` gap)

- [x] Stock Arch has no `cachyos-rate-mirrors`. The Arch-native replacement is
      **reflector** ([extra](https://archlinux.org/packages/extra/any/reflector/),
      [ArchWiki Reflector](https://wiki.archlinux.org/title/Reflector)):
      `sudo pacman -S --needed reflector && sudo reflector --latest 10 --protocol https --age 12 --sort rate --save /etc/pacman.d/mirrorlist`
      (the wiki's canonical test-prep form uses `--latest 5`; 10 gives the VM
      proof a spare mirror or two).
- [x] Fallback already in the official repos, per
      [ArchWiki Mirrors § Sorting](https://wiki.archlinux.org/title/Mirrors):
      `rankmirrors` from **pacman-contrib** (`/usr/bin/rankmirrors`, verified
      owned by `pacman-contrib` on this box), and **rate-mirrors** /
      **mirro-rs**, both linked from the wiki as official-repo packages.
      `rate-mirrors` is the closest spiritual stand-in for the CachyOS rater.
- [x] Test-prep ordering matters: reflector itself comes from the repos, so a
      dead default mirror is fixed the CachyOS way in reverse — hand-seed one
      known-good mirror (or the
      [mirrorlist generator](https://archlinux.org/mirrorlist/)) before running
      reflector, same role `cachyos-rate-mirrors` played in the #92 proof.

## 1. yay bootstrap via git + makepkg

- [x] Equivalent on stock Arch, no delta. `git clone
      https://aur.archlinux.org/yay.git && makepkg -si` is the AUR-endorsed
      build path on any Arch system, CachyOS or stock.
- [x] `base-devel` is an Arch-defined group (all members are core-repo
      packages); CachyOS does not fork it, so group contents are identical.
      `install.sh` only needs two things from it working: `makepkg` (ships in
      the `pacman` package) and a C toolchain — both present either way.
- [x] One baseline precondition, not a delta: `makepkg` **refuses to run as
      root**, so the proof guest must build yay as the non-root user with
      passwordless-or-tty sudo (same as the CachyOS proof did).

## 2. sudo / network preconditions on a minimal install

- [x] `install.sh` line 56–58 runs `sudo pacman` as its first privileged act —
      `sudo` exists in Arch **core** (`core sudo 1.9.17.p2-6`, verified in sync
      DB) but a minimal Arch install ships **neither sudo nor a non-root
      user**. The proof baseline must therefore provision, before `install.sh`
      ever runs: a user, `sudo` installed, wheel membership
      (`EDITOR=visudo visudo`, uncomment `%wheel ALL=(ALL:ALL) ALL`).
- [x] Network: same story — minimal Arch has no NetworkManager running by
      default, and `install.sh`'s runtime group installs `networkmanager` but
      never enables it. Baseline must have working network at proof time
      (archinstall's NetworkManager profile, or manual `systemctl
      enable NetworkManager`), matching the handoff's "already-installed
      system with sudo + network" assumption.
- [x] Decision for the baseline ticket: `install.sh` itself stays unchanged
      (it must run as non-root + sudo, same contract as CachyOS); sudo/user/
      network are **guest-snapshot** responsibilities, not script changes.

## 3. gum / fuse2 / gtk-layer-shell availability and names on Arch

- [x] **gum**: official **extra**, same name —
      [archlinux.org gum 2.0.2-1](https://archlinux.org/packages/extra/x86_64/gum/).
      `install.sh` line 86 `pacman -S gum` works verbatim.
- [x] **fuse2**: official **extra**, same name (`extra fuse2 2.9.9-6`,
      verified in sync DB). Handy AppImage runtime dep resolves identically.
- [x] **gtk-layer-shell**: official **extra**, same name (`extra
      gtk-layer-shell 0.10.1-1`, verified in sync DB). No rename, no AUR
      detour needed for any of the three.

## 4. No-AUR installers are distro-agnostic in practice

- [x] **mise pipe** (`curl -fsSL https://mise.run | sh`, `install.sh:111`):
      HTTP 200, live. The fetched script is OS detection via `uname -s` /
      `uname -m` only (linux → x64/arm64/armv7 (+musl), mac handled, else
      error) — no distro sniffing anywhere. Hard requirements are
      `curl|wget` + `tar` + `shasum|sha256sum`, and it installs to
      `$HOME/.local/bin/mise`. `curl` is guaranteed present because
      `install.sh` installs `git` first and `git` depends on `curl`
      (verified: `Depends On: curl …` in both extra and cachyos trees).
      Verdict: portable, no change.
- [x] **mise Node 24** (`.mise.toml` pins `node = "24"`; `mise install` +
      `mise use -g node@24`): mise's core node backend downloads prebuilt
      nodejs.org binaries and **GPG-verifies them by default**
      ([mise node docs](https://mise.jdx.dev/lang/node.html)). Only needs a
      current glibc — stock Arch glibc is newer than CachyOS's, never older.
      Verdict: portable, no change.
- [x] **opencode npm global** (`npm install -g opencode-ai@1.18.34`):
      `registry.npmjs.org/opencode-ai/latest` returns **1.18.34** with an
      `opencode-linux-x64` optional dependency and `_nodeVersion 24.13.0`
      (matches the mise Node 24 pin — the toolchain is self-consistent).
      Pure npm payload, no distro hooks. Verdict: portable, no change.
- [x] **zed script** (`curl -fSL https://zed.dev/install.sh | sh`):
      HTTP 200, live. Script logic is `uname`-based platform/arch select,
      `curl|wget` download of a tarball from `cloud.zed.dev`, `tar -xzf`
      into `~/.local/`, symlink into `~/.local/bin` — zero distro
      assumptions, and it even `ldd`s the binary post-install to warn about
      missing system libs instead of assuming them. Verdict: portable, no
      change.
- [x] **Handy AppImage** (pinned `v0.9.7` asset): the exact release URL
      `github.com/cjpais/Handy/releases/download/v0.9.7/Handy_0.9.7_amd64.AppImage`
      resolves HTTP 200 (via release-assets redirect). AppImage needs a
      FUSE2-capable kernel helper + `gtk-layer-shell` — both confirmed
      same-named in Arch extra (§3). The install.sh SHA256 pin
      (`HANDY_SHA256`) is upstream-asset content, distro-independent.
      Verdict: portable, no change.

## Bottom line

Every bootstrap step has a green Arch verdict: mirrors → reflector one-liner
(§0); yay/base-devel identical (§1); sudo+user+network are snapshot
responsibilities, not script changes (§2); gum/fuse2/gtk-layer-shell same names
in extra (§3); all five no-AUR installers distro-agnostic as written (§4).
**No `install.sh` portability fix is scoped from this ticket** — the remaining
Arch risk sits in the main payload packages, which is ticket #95's question.
