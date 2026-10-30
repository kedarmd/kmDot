# Fresh Arch VM validation

**Run date:** 2026-10-31
**Guest:** Arch Linux x86_64, 2 vCPU, 3 GiB RAM, QEMU/KVM, `testuser`
**Install path:** `install.sh --all`, then `config-install.sh --all`, followed by the first-login sync actions documented below.

This records an end-to-end install on a clean Arch VM and a smoke pass from its running Hyprland session. The VM was left booted so the setup can be checked interactively.

## Automated smoke check

Run `tests/fresh-arch-smoke.sh` as the target user inside a running Hyprland session. It can also be launched over SSH: it reads the Wayland and Hyprland variables from the live QuickShell process because those are not inherited by SSH shells.

The final run passed all 17 checks:

- Neovim loads the installed configuration, edits a buffer, and writes the result.
- Hyprland is running and returns a monitor through `hyprctl`.
- QuickShell responds to IPC; its app launcher opens and closes.
- Ghostty, Herdr, Zen Browser, Firefox, Zed, OpenCode, Fish, and Starship start and report versions or execute a simple command. Handy loads its model catalog.
- Tmux starts a session with the installed config and closes it.
- SDDM is enabled, NetworkManager is active, `en_IN.UTF-8` is generated, and `pacman -Qm` is empty.

Result: **17 passed, 0 failed**.

The existing Node launcher suite also passed: **117 passed, 0 failed, 1 skipped**. The skipped case requires an installed Omarchy menu, which this kmDot-only VM does not have.

## Findings applied to the repository

- Herdr installs using its official `https://herdr.dev/install.sh` script. The repository pins the script checksum; the installer verifies the downloaded binary against Herdr's manifest. The installed CLI and server reported version 0.9.5, and workspace listing worked. See [Herdr's install page](https://herdr.dev/download/).
- Removed the `yay` bootstrap and AUR fallback from `install.sh`. Package names unavailable in official repositories now fail with an explicit message; no AUR helper is installed or invoked.
- Zen Browser now installs from a versioned official upstream release tarball with a pinned SHA-256 because the previous `zen-browser` package path was unavailable without AUR. The installed binary reported 1.24b. See [Zen's Linux install docs](https://docs.zen-browser.app/guides/install-linux).
- Added Neovim's native build prerequisites (`gcc`, `make`) for the configured `telescope-fzf-native` plugin.
- Added QuickShell runtime modules `qt6-multimedia`, `qt6-multimedia-ffmpeg`, and `qt6-5compat`, discovered as missing during real configuration startup.
- Added `ripgrep`, used by the theme switcher, and `git` to the official package list.
- Made the first `config-install.sh --all` QuickShell sync pass the default theme when no theme cache exists yet.
- `sync/system.sh` now generates the configured `en_IN.UTF-8` locale on fresh installs.
- `sync/sddm.sh` enables SDDM so a reboot reaches the graphical login screen.
- Fixed compatibility color references in the migrated QuickShell launcher code after the app launcher exposed a QML built-in name collision.

## Installation observations

The first exploratory run started before the no-AUR constraint was given and installed `yay`, `yay-debug`, and `herdr-bin`; a Zen AUR build also began. That build was stopped, the AUR packages and yay cache were removed, Firefox was installed from pacman, and the installer was changed to avoid AUR. The completed clean run used the official Herdr installer and official Zen release instead. Final `pacman -Qm` output was empty.

Configuration sync completed, the user shell changed to Fish, SDDM displayed the configured greeter, and authentication launched the Hyprland session with no Hyprland config errors. QuickShell loaded its full configuration without QML errors, served its launcher socket, opened and closed the app launcher over IPC, and launched Ghostty through the app launcher. Ghostty was visible as a live Hyprland client. A theme switch to Nord and back to Tokyo Night also completed and QuickShell re-bound its launcher socket after each restart.

## Hardware and environment limits

This VM has no physical Bluetooth adapter or audio device. QuickShell logs the expected BlueZ D-Bus warning and PipeWire reports a dummy output, so actual Bluetooth pairing, microphone capture, and audible playback could not be verified here. QuickShell's multimedia modules and full configuration load. Display output also shows QEMU/Mesa rendering artifacts; this limits visual sign-off but did not prevent IPC or application startup checks.

The VM uses a 60 GiB virtual disk, has no attached ISO on reboot, and remains available for interactive verification. Temporary provisioning-only passwordless sudo and swap-file changes were removed after installation; the test user retains ordinary password-protected sudo access.
