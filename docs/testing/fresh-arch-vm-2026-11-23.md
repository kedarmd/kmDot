# Fresh Arch VM validation — 2026-11-23

This run repeated the fresh install against the current GitHub `main` branch. It used the Arch ISO already in `~/Downloads` and a new UEFI QEMU/KVM guest.

## Result

- `git clone https://github.com/kedarmd/kmDot.git` completed.
- `./install.sh --all` completed with no failed packages.
- `./config-install.sh --all` completed with no failed syncs and applied Tokyo Night.
- After reboot, SDDM logged into the configured Hyprland session and QuickShell loaded.
- `tests/fresh-arch-smoke.sh`: **16 passed, 0 failed** after removing its Firefox check. Firefox was not installed by the repository scripts and is not part of the desired setup; Zen Browser is the configured browser.
- `pacman -Qm` was empty in the smoke check: no AUR/foreign packages were installed.
- The tested Zen installation is the pinned, checksum-verified upstream tarball managed by `install.sh`. Zen also publishes an AppImage, but that alternative was not tested in this run ([official Linux install guide](https://docs.zen-browser.app/guides/install-linux)).
- Follow-up validation added Herdr App to `install.sh --all`; see [Herdr App follow-up](#herdr-app-follow-up).

The first smoke run had 16 passes and one Firefox failure. As in the October exercise, Firefox had been installed manually and is not in `install.sh`; it is not needed for this setup. The check is now removed from `tests/fresh-arch-smoke.sh`. Zen Browser passed.

## VM and ISO choices

| Setting | Value |
|---|---|
| ISO | `~/Downloads/archlinux-x86_64.iso`, label `ARCH_202610`, version `2026.10.01` |
| ISO SHA-256 | `684ded26c63240ff4a41e8c25ee84ea6da233f557364821f13d12c2b0a9059a5` |
| Firmware | UEFI (OVMF) |
| Virtualization | QEMU/KVM, 2 vCPUs, 3 GiB RAM |
| Disk | 50 GiB sparse qcow2, virtio; GPT with 1 GiB EFI and ext4 root |
| Network | QEMU user-mode NAT |
| Bootloader | systemd-boot |
| Hostname / user | `arch-kmdot-test` / `testuser` with sudo |
| Locale / timezone | Initially `en_US.UTF-8`, US keymap, `Asia/Kolkata`; the config sync generated `en_IN.UTF-8` too |
| Swap / encryption | None |

The first VM creation attempt asked for a 60 GiB disk, which exceeded the host's free pool capacity. I changed it to a 50 GiB sparse qcow2 disk and allowed the virtual capacity to exceed currently free host space. It used only the guest's actual written data. The test guest was kept separate from the host's dotfiles.

## Install Arch on a new machine

Boot the Arch ISO in UEFI mode and connect it to the internet. The live ISO logs in as root. On a bare machine, replace `/dev/vda` below with the correct target disk; these commands erase that disk.

Create the same simple partition layout used by this VM:

```bash
loadkeys us
wipefs -af /dev/vda
sgdisk --zap-all /dev/vda
sgdisk --new=1:0:+1G --typecode=1:EF00 --change-name=1:EFI /dev/vda
sgdisk --new=2:0:0 --typecode=2:8300 --change-name=2:ArchRoot /dev/vda
partprobe /dev/vda
mkfs.fat -F32 /dev/vda1
mkfs.ext4 -F /dev/vda2
mkdir -p /mnt/archinstall
mount /dev/vda2 /mnt/archinstall
mkdir -p /mnt/archinstall/boot
mount /dev/vda1 /mnt/archinstall/boot
```

Create `/tmp/config.json` with these Archinstall choices:

```json
{
  "archinstall-language": "English",
  "bootloader": "Systemd-boot",
  "bootloader_config": {
    "bootloader": "Systemd-boot",
    "uki": false,
    "removable": false
  },
  "disk_config": {
    "config_type": "pre_mounted_config",
    "mountpoint": "/mnt/archinstall"
  },
  "hostname": "arch-kmdot-test",
  "kernels": ["linux"],
  "locale_config": {
    "kb_layout": "us",
    "sys_enc": "UTF-8",
    "sys_lang": "en_US.UTF-8"
  },
  "ntp": true,
  "packages": [
    "base-devel", "curl", "git", "jq", "networkmanager",
    "openssh", "sudo", "vim"
  ],
  "script": "guided",
  "silent": true,
  "swap": false,
  "timezone": "Asia/Kolkata",
  "custom_commands": ["systemctl enable NetworkManager sshd"]
}
```

Create `/tmp/creds.json` with one sudo user. Generate a password hash locally in the live ISO and insert it in place of `HASH`:

```bash
openssl passwd -6
```

```json
{
  "users": [
    {"username": "testuser", "sudo": true, "enc_password": "HASH"}
  ]
}
```

Then start the guided installation:

```bash
archinstall --config /tmp/config.json --creds /tmp/creds.json --silent
```

When it completes, reboot, remove the ISO, and log in as the user you created. The actual run used the same temporary password for the guest login and sudo; no password or hash is recorded here.

### Slow mirror recovery

The first Archinstall attempt stopped when a package transfer from the selected mirror fell below pacman's low-speed timeout. I retried after adding `DisableDownloadTimeout` under `[options]` in `/etc/pacman.conf` in the live ISO, then reran the disk/install commands. The retry completed. This was an ISO mirror transfer issue, not a kmDot script failure.

If the same timeout happens, add the option and retry:

```bash
sed -i '/^\[options\]/a DisableDownloadTimeout' /etc/pacman.conf
```

## Install kmDot from GitHub

Log into the new Arch system as the sudo user and run the exact script sequence tested here:

```bash
git clone https://github.com/kedarmd/kmDot.git
cd kmDot
./install.sh --all
./config-install.sh --all
```

The installer bootstrapped `gum`, installed mise and Node.js 24, installed the official Arch packages and upstream app releases, generated `en_IN.UTF-8`, and changed the login shell to Fish. Config sync installed the polkit rule, enabled NetworkManager and Bluetooth, enabled SDDM, synced all selected application configs, cloned TPM for tmux, and applied Tokyo Night.

Reboot after config sync. At the SDDM screen, select the Hyprland session if it is not already selected, then log in. A Fish startup warning that `~/.config/fish/secrets.fish` is absent is expected on a clean clone because that private file is gitignored; it does not block the shell or smoke checks.

## Validate the configured session

From a terminal in the live Hyprland session, run:

```bash
cd ~/kmDot
./tests/fresh-arch-smoke.sh
```

The checks cover Neovim, Hyprland config and monitor access, QuickShell IPC and launcher, Ghostty, Herdr, Zen Browser, Zed, OpenCode, Handy's model catalog, Fish, Starship, tmux, SDDM, NetworkManager, the `en_IN.UTF-8` locale, and absence of foreign packages. The completed run produced 16 passes and 0 failures.

## Time and limits

The host's Wi-Fi made the clone and several large upstream downloads noticeably slow. The GitHub clone received about 116 MiB. The long downloads were the Arch base package set, Handy, OpenCode, and Zen Browser; each completed without changing the install scripts. Allow extra time on a slow connection. If a pacman transfer stalls, use the mirror recovery above.

The guest had a virtual display and network only. The smoke run exercised the Hyprland session and QuickShell IPC, but could not validate physical Bluetooth pairing, microphone input, or audible output. The guest remained available as `kmdot-arch-repeat-20261123` in the host's libvirt session at the end of this run.

## Herdr App follow-up

Herdr's [official download page](https://herdr.dev/download/) lists `curl -fsSL https://releases.herdr.dev/app/install.sh | sh`. `install.sh` downloads that script, verifies its pinned SHA-256, then runs it; the upstream installer verifies the app archive against its release manifest. `herdr-app` is now included in the interactive app picker and `--all` defaults. The Arch package map includes `libxcb` and `libxkbcommon`, which the app binary needs at runtime.

Focused validation used a separate Arch VM cloned from the clean OS image. The installer's `herdr-app` picker entry installed Herdr App **0.1.16** and `herdr-core` **0.1.22**. The first launch check found the missing `libxcb.so.1` and `libxkbcommon.so.0`; after adding both packages, `ldd` resolved all direct shared-library dependencies and the app launcher and desktop entry were present. The full 17-check smoke suite was not run in this minimal validation VM because it has no Hyprland session. Its Herdr App check now verifies the executable, desktop entry, and dynamic libraries in a full session.

The clean guest for a hands-on run is `kmdot-arch-selftest-20261123`. It is a separate base Arch install, with no repository clone or kmDot scripts run. It uses the ISO and OS choices above, a 30 GiB sparse qcow2 disk, and is left at the `testuser` login prompt. Launch it from the host with:

```bash
virt-viewer --connect qemu:///session kmdot-arch-selftest-20261123
```

After logging in, start the test from the public repository:

```bash
git clone https://github.com/kedarmd/kmDot.git
cd kmDot
./install.sh --all
./config-install.sh --all
```

## Installer additions: Codex, Pi, and Hex

The installer now includes Codex CLI (`@openai/codex` v0.171.0) and Pi (`@mariozechner/pi-coding-agent` v0.73.1) from their official npm packages through mise. Handy remains a default app and the default dictation provider. Hex is included in `install.sh --all` and uses the [official Linux installer](https://github.com/anomalyco/hex/blob/dev/docs/linux.md#install-a-published-build), pinned by installer-script SHA-256; that installer verifies the signed Hex release. Its runtime libraries and Wayland paste helpers are installed from official Arch repositories. No AUR package or helper is used.

Hex's initial model download is a separate first-launch step (`~/.local/bin/hex model install`); it can take longer than the app install depending on connection speed. The kmDot QuickShell sync disables Hex's independent autostart and selects Handy by default, so Hex remains available for manual provider switching without replacing Handy at login.

On 2026-11-23, the updated scripts were pulled into `kmdot-arch-selftest-20261123` and run directly. An initial attempt stopped at sudo while installing `openblas`; after reboot, the supplied test-user password authenticated and the full install completed. `./install.sh --all` installed Hex 3.4.0 and Pi 0.73.1, and reported `All done!`. `./config-install.sh --all` then completed every sync, including SDDM and system steps, and printed `All done!`. The final `./tests/fresh-arch-smoke.sh` run passed **21 checks, 0 failures**. This included Codex and Pi startup, Hex CLI startup, Handy's model catalog, Handy as the selected default provider, and an empty foreign/AUR package list. The only previously absent Hex runtime packages were `openblas` and `wtype`; both were installed from the official Arch repositories using the dependency list in `install.sh`. No further missing runtime libraries were reported.
