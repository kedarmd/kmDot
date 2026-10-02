# Research: Zed official binary install truth

Ticket: [#89](https://github.com/kedarmd/kmDot/issues/89) (child of map #86).
Question: what is the official non-AUR Zed Linux install — install script vs
release tarball, paths, .desktop entry, update story, dependencies — shaped to
fit a non-interactive `install.sh` step with skip-if-present idempotency and
failure reporting? Cargo-from-source is RULED OUT (charting decision); official
binary only. Verified 2026-10-02 against the sources at the bottom.

## TL;DR

- Run the official script non-interactively in `install.sh`:
  `curl -f https://zed.dev/install.sh | sh` (stable; `ZED_CHANNEL=preview sh`
  for preview). The script is `#!/usr/bin/env sh` + `set -eu`, takes no
  arguments, prompts nothing, needs no sudo (all user-local under `~/.local`).
- Idempotency: `command -v zed &>/dev/null` → skip ("already installed"),
  matching the existing `FAILED_PKGS` loop shape. Re-running the script is also
  safe (it `rm -rf`s `~/.local/zed.app` and re-extracts), so skip-if-present is
  a speed optimization, not a correctness requirement.
- Updates need NO install.sh work: script-installed Zed self-updates (checks in
  background, applies on restart; opt-out via the `auto_update` setting).
- Deps on a kmDot box are already covered except GPU drivers: `curl` + `gnome-keyring`
  are in the `runtime` group, `xdg-desktop-portal*` has its own group; Vulkan-capable
  GPU drivers are external (per-GPU packages, can't be scripted generically).

## 1. Install script (recommended path)

- **URL:** `https://zed.dev/install.sh` — served copy of
  [`script/install.sh`](https://github.com/zed-industries/zed/blob/main/script/install.sh)
  in `zed-industries/zed` (verified identical by inspection: `main()` platform/arch
  detect, `linux()` download → unpack → link → .desktop).
- **Commands:**
  ```sh
  curl -f https://zed.dev/install.sh | sh                                  # stable (default)
  curl -f https://zed.dev/install.sh | ZED_CHANNEL=preview sh              # preview (~1 week ahead)
  curl -f https://zed.dev/install.sh | ZED_VERSION=0.216.0 sh               # pinned version
  ```
- **Env knobs** (all read by the script, all optional): `ZED_CHANNEL`
  (`stable` default; `preview`/`nightly`/`dev` change the app dir suffix AND the
  .desktop app-id, see §3), `ZED_VERSION` (`latest` default; pins a version),
  `ZED_BUNDLE_PATH` (use a pre-downloaded tarball instead of curl — offline path),
  `TMPDIR` (override temp dir).
- **Non-interactive fit:** no prompts, no sudo, exit-nonzero on failure
  (`set -eu`, `curl -fL`, unsupported platform/arch → `exit 1`, missing both
  curl and wget → `exit 1`). Only requirement: `curl` OR `wget` on PATH
  (`curl` is already in kmDot's `runtime` group). The script's only stdout-at-end
  branch is a PATH hint when `~/.local/bin/zed` is not on PATH — kmDot fish
  config must keep `~/.local/bin` on PATH or the binary is unreachable.
- **Suggested install.sh step** (same collect-don't-abort shape as the
  `FAILED_PKGS` loop in `install.sh:189-228`):
  ```sh
  if command -v zed &>/dev/null; then
    echo "  zed: already installed."
  elif err=$(curl -f https://zed.dev/install.sh | sh 2>&1); then
    echo "  zed: done."
  else
    echo "  zed: FAILED"; echo "    $err" | head -5
    FAILED_PKGS+=("zed")
  fi
  ```

## 2. Release tarball (same artifact, manual control)

- **What:** the `.tar.gz` the script downloads — use directly when pinning,
  vendoring, or installing off-network (`ZED_BUNDLE_PATH`).
- **URLs (stable, per [linux docs](https://zed.dev/docs/linux)):**
  - x86_64: `https://cloud.zed.dev/releases/stable/latest/download?asset=zed&arch=x86_64&os=linux&source=docs`
    (preview: same with `/preview/`)
  - aarch64: same with `arch=aarch64`
  - GitHub mirror per release: `https://github.com/zed-industries/zed/releases/download/<tag>/zed-linux-<x86_64|aarch64>.tar.gz`
    (e.g. v1.22.0 assets verified live; plus `zed-remote-server-*` and `bwrap-*`
    assets — NOT needed for desktop install).
- **Manual steps** (from the docs; the script automates exactly this):
  ```sh
  mkdir -p ~/.local
  tar -xvf <download>.tar.gz -C ~/.local          # → ~/.local/zed.app/
  ln -sf ~/.local/zed.app/bin/zed ~/.local/bin/zed
  ```
- **Verdict:** prefer the script in `install.sh` (one line, handles arch +
  .desktop + icon/exec rewrites). Tarball only if a pinned/offline install is
  ever needed — then set `ZED_BUNDLE_PATH` and still run the script.

## 3. Install paths (stable channel)

| Path | What |
|---|---|
| `~/.local/zed.app/` | Whole install: `bin/zed` (CLI/launcher shim), `libexec/zed-editor` (real binary — the one the script `ldd`-checks), `share/applications/*.desktop`, `share/icons/.../zed.png` |
| `~/.local/bin/zed` | Symlink → `~/.local/zed.app/bin/zed` (pre-0.139 tarballs: `bin/cli`) |
| `~/.local/share/applications/dev.zed.Zed.desktop` | Copied from the tarball, then rewritten (see §4) |

- Non-stable channels suffix the dir AND rename the app-id:
  `~/.local/zed-preview.app` + `dev.zed.Zed-Preview.desktop`
  (`-nightly` → `dev.zed.Zed-Nightly`, `-dev` → `dev.zed.Zed-Dev`).
- Nothing lands outside `$HOME`: no root, no `/usr`, no pacman/yay involvement —
  this is what makes the no-AUR requirement trivially satisfiable.
- Uninstall: `zed --uninstall` (handles the symlinked variant; absolute path
  `~/.local/zed.app/bin/zed --uninstall` for parallel stable+preview installs).
  Note: it interactively asks whether to keep preferences — no `--force` flag
  exists, so uninstall stays a manual step, not an install.sh verb.

## 4. .desktop entry handling

The script copies the tarball's desktop file to
`~/.local/share/applications/` and rewrites the two bare names to absolute paths:
```sh
cp "$HOME/.local/zed.app/share/applications/dev.zed.Zed.desktop" ~/.local/share/applications/
sed -i "s|Icon=zed|Icon=$HOME/.local/zed.app/share/icons/hicolor/512x512/apps/zed.png|g" ...
sed -i "s|Exec=zed|Exec=$HOME/.local/zed.app/bin/zed|g" ...
```
Launcher impact: the app-launcher matcher sees `dev.zed.Zed.desktop` with an
absolute `Exec` — no repo-side change needed; the entry appears like any
user-local desktop file after install (no `update-desktop-database` call in the
script — runtimes pick up `~/.local/share/applications` on scan).

## 5. Update story

- **Self-updating:** per [Update Zed](https://zed.dev/docs/update), Zed "checks
  for updates and installs them automatically … download[s] in the background
  and appl[ies] on restart". Script-installed builds use this path, so
  `install.sh` never needs a re-install/upgrade step.
- **Control:** Settings Editor → General → Auto Update (`auto_update` key);
  packagers can bake in `ZED_UPDATE_EXPLANATION` ("Please use flatpak…") —
  irrelevant for script installs, noted only so nobody copies it.
- **Manual:** re-run the script (gets `latest`) or set `ZED_VERSION=<x>` to
  pin/move. Preview channel tracks ~1 week ahead of stable.
- **What install.sh must NOT do:** no version check, no upgrade logic, no cron —
  skip-if-present + Zed's own updater covers it.

## 6. System dependencies

- **glibc floor** (hard fail otherwise — `GLIBC_x.xx not found`, only fix is
  upgrade or build from source): x86_64 ≥ 2.31 (Ubuntu 20+), aarch64 ≥ 2.35
  (Ubuntu 22+). CachyOS/Arch rolling is far above both — non-issue here, noted
  for the record.
- **Vulkan GPU + drivers** (Zed renders via Vulkan; `NoSupportedDeviceFound` =
  no compatible GPU): needs per-GPU driver packages (`vulkan-radeon` for AMD —
  NOT `amdvlk`, which is a known-broken combo per the docs; NVIDIA/Intel via
  their usual stacks). Not scriptable generically → document as a VM/host
  prerequisite, not an install.sh dep. Debug path: `vkcube [-m x11|wayland]`,
  GPU line in `~/.local/share/zed/logs/Zed.log`, `ZED_DEVICE_ID=0x…` /
  `MESA_VK_DEVICE_SELECT` overrides.
- **Script self-check:** after unpacking, the script `ldd`s
  `libexec/zed-editor` and prints missing libs as a warning (non-fatal).
  Failure mode for install.sh: install succeeds but Zed won't start — surface
  by echoing the warning through, or re-running the `ldd … not found` check
  post-install and treating hits as a failure entry.
- **Already-in-repo coverage:** `curl` (downloader) and `gnome-keyring`
  (Secret portal — logins/API keys) are in the `runtime` group;
  `xdg-desktop-portal` + `-hyprland` have their own group (FileChooser/OpenURI
  portals). PipeWire audio needs the ALSA→PipeWire shim only on ALSA-only
  setups (kmDot runs PipeWire — non-issue). inotify/file-descriptor limits only
  bite on giant monorepos (`fs.inotify.max_user_watches=64000`).

## Sources (primary only)

- `https://zed.dev/docs/linux` — standard install, tarball + .desktop manual
  steps, uninstall, glibc/Vulkan/portals/keyring/inotify troubleshooting.
- `https://zed.dev/install.sh` — the script itself (platform/arch detect,
  channel/version/bundle env vars, unpack/link/desktop/ldd-check logic).
- `https://github.com/zed-industries/zed/blob/main/script/install.sh` — canonical
  repo copy of the same script.
- `https://zed.dev/docs/installation` — channel/version matrix
  (`ZED_CHANNEL`, `ZED_VERSION`), supported distros incl. Arch.
- `https://zed.dev/docs/update` — auto-update behavior + opt-out.
- `https://github.com/zed-industries/zed/releases` (latest v1.22.0 verified
  2026-10-02) — per-version `zed-linux-<arch>.tar.gz` assets (desktop) vs
  `zed-remote-server-*`/`bwrap-*` (not needed).
- `https://zed.dev/docs/development/linux.md` — `ZED_UPDATE_EXPLANATION`,
  `script/linux` system-dep installer, `./script/install-linux` (source path —
  explicitly NOT recommended per map constraint).
