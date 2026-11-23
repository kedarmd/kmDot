# Fresh Arch install and kmDot setup

This guide follows the install from the first ISO boot through the kmDot smoke test. Follow the numbered sections in order. Arch is installed first; clone the repository only after the new system boots and you can sign in.

## 1. Prepare and boot the Arch ISO

Download the official x86_64 ISO and its signature from [archlinux.org](https://archlinux.org/download/), then verify the ISO before booting it. The validation run used `~/Downloads/archlinux-x86_64.iso`, version `2026.10.01`, SHA-256 `684ded26c63240ff4a41e8c25ee84ea6da233f557364821f13d12c2b0a9059a5`.

Boot the installer in UEFI mode. The VM used UEFI with systemd-boot. No desktop environment, browser, AUR helper, or AUR package was installed during the Arch install.

Set the live ISO keyboard layout and connect to the internet. Ethernet with DHCP works directly. For Wi-Fi, first find the interface name with `iwctl device list` (often `wlan0`), then connect:

```text
iwctl
[iwd]# device list
[iwd]# station wlan0 scan
[iwd]# station wlan0 get-networks
[iwd]# station wlan0 connect YOUR_WIFI_NAME
[iwd]# exit
```

Check that the connection works and the live system clock is synchronized before installing:

```bash
ping -c 3 ping.archlinux.org
timedatectl
```

The live ISO synchronizes time after network connectivity is established. See the [ArchWiki installation guide](https://wiki.archlinux.org/title/Installation_guide#Connect_to_the_internet).

Identify the target disk with `lsblk`. The VM used `/dev/vda`; a laptop may show `/dev/nvme0n1` or `/dev/sda`. The commands below erase the selected disk. Replace `/dev/vda`, `/dev/vda1`, and `/dev/vda2` consistently with the correct disk and partition names for your machine before running them.

## 2. Partition and mount the disk

The tested layout is GPT, a 1 GiB EFI System Partition, and an ext4 root partition using the rest of the disk. There is no swap partition or disk encryption in this setup.

In the live ISO shell, set the keyboard layout and create the partitions. **Double-check the disk name before running `wipefs` or `sgdisk`; these commands erase that disk.**

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

## 3. Install the Arch base system

Archinstall installed the base bootable system and the Linux kernel. The explicit package list supplied in Archinstall was:

```text
base-devel curl git jq networkmanager openssh sudo vim
```

These are the only extra packages selected during the OS install. The desktop and workstation applications are installed later by kmDot.

Create `/tmp/config.json` in the live ISO. This matches the clean self-test VM; change the hostname if you want a different one.

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
  "hostname": "arch-kmdot-selftest",
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

Create `/tmp/creds.json` with the sudo user. Generate a temporary password hash locally and put it in place of `HASH`. Use the same password when signing in and when sudo prompts; keep it private and out of the repository.

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

Run the Arch installer:

```bash
archinstall --config /tmp/config.json --creds /tmp/creds.json --silent
```

When it completes, reboot, remove/eject the ISO, and sign in as `testuser`. Confirm sudo works before continuing:

```bash
sudo -v
```

## 4. Clone kmDot and install the workstation

Only after logging into the installed Arch system, clone the public repository and run the two install scripts in order:

```bash
git clone https://github.com/kedarmd/kmDot.git
cd kmDot
./install.sh --all
./config-install.sh --all
```

`install.sh --all` installs packages from the official Arch repositories and approved upstream sources. It bootstraps gum, mise, and Node.js 24; installs the selected apps; and generates `en_IN.UTF-8`. `config-install.sh --all` syncs app configs, installs the polkit rule, enables the required services and SDDM, changes the login shell to Fish, clones TPM for tmux, and applies Tokyo Night. No AUR helper or AUR package is used.

Reboot after both scripts complete. At SDDM, select the Hyprland session if it is not already selected, then sign in. A Fish warning that `~/.config/fish/secrets.fish` is absent is expected on a clean clone; that private file is gitignored and the warning does not block the shell or smoke checks.

## 5. Run the smoke check

From a terminal in the logged-in Hyprland session:

```bash
cd ~/kmDot
./tests/fresh-arch-smoke.sh
```

The latest run passed **21 checks, 0 failures**. Checks cover Neovim, Hyprland and monitor access, QuickShell IPC and launcher, Ghostty, Herdr, Herdr App, Codex, Zen Browser, Zed, OpenCode, Pi, Handy's model catalog, Hex, Handy as the default provider, Fish, Starship, tmux, SDDM, NetworkManager, `en_IN.UTF-8`, and the absence of foreign/AUR packages.

## Installation details and recovery

### VM choices used for validation

| Setting | Value |
|---|---|
| ISO | `~/Downloads/archlinux-x86_64.iso`, label `ARCH_202610`, version `2026.10.01` |
| ISO SHA-256 | `684ded26c63240ff4a41e8c25ee84ea6da233f557364821f13d12c2b0a9059a5` |
| Firmware | UEFI (OVMF) |
| Virtualization | QEMU/KVM, 2 vCPUs, 3 GiB RAM |
| Disk | Repeat VM: 50 GiB sparse qcow2; clean self-test VM: 30 GiB sparse qcow2. Both use GPT, 1 GiB EFI, and ext4 root. |
| Network | QEMU user-mode NAT |
| Bootloader | systemd-boot |
| Hostname / user | Repeat VM: `arch-kmdot-test`; self-test VM: `arch-kmdot-selftest`; user: `testuser` with sudo. |
| Locale / timezone | Initially `en_US.UTF-8`, US keymap, `Asia/Kolkata`; kmDot also generated `en_IN.UTF-8`. |
| Swap / encryption | None |

The first VM creation attempt asked for a 60 GiB disk, which exceeded the host's free pool capacity. The repeat VM used a 50 GiB sparse disk; the clean self-test VM used a 30 GiB sparse disk. On a laptop, size the root partition for your needs; the tested layout allocates 1 GiB to EFI and the rest to ext4 root.

### Slow mirror recovery

The first Archinstall attempt stopped when a package transfer from the selected mirror fell below pacman's low-speed timeout. I added `DisableDownloadTimeout` under `[options]` in `/etc/pacman.conf` in the live ISO and reran the installation. If the same timeout occurs, use:

```bash
sed -i '/^\[options\]/a DisableDownloadTimeout' /etc/pacman.conf
```

### Apps, sources, and extra dependencies

- Handy is installed by default and remains the default dictation provider. Hex is available as the alternate provider.
- Codex CLI (`@openai/codex`) v0.171.0 and Pi (`@mariozechner/pi-coding-agent`) v0.73.1 install through mise from official npm packages.
- Hex 3.4.0 uses the [official Linux installer](https://github.com/anomalyco/hex/blob/dev/docs/linux.md#install-a-published-build), pinned by installer-script SHA-256. The upstream installer verifies the signed release. Its first speech model download is separate: `~/.local/bin/hex model install`.
- Hex required `openblas` and `wtype`, installed from official Arch repositories. Its other documented runtime packages are listed in `install.sh`; the completed run reported no further missing libraries.
- Herdr App installs using Herdr's [official installer](https://herdr.dev/download/). Its binary required `libxcb` and `libxkbcommon`, which `install.sh` installs from official repositories.
- Zen Browser installs from the pinned, checksum-verified upstream tarball in `install.sh`. Its [official Linux guide](https://docs.zen-browser.app/guides/install-linux) also offers an AppImage; the tarball route was the one tested.
- Firefox is not part of the desired setup; Zen Browser is used instead.

The host Wi-Fi made the clone and several downloads slow. The GitHub clone received about 116 MiB. The longest downloads were the Arch base package set, Handy, OpenCode, Zen Browser, and npm apps; Pi took about a minute in the latest run. Hex itself installed promptly after dependencies were available, while its speech model is a separate first-run download. If a pacman transfer stalls, use the mirror recovery above.

The VM had virtual display and network only. The test exercised Hyprland and QuickShell IPC, but not physical Bluetooth pairing, microphone input, or audible output. The smoke checks passed with no foreign/AUR packages.

Earlier Herdr App validation in a separate VM installed Herdr App **0.1.16** and `herdr-core` **0.1.22**. Initial launch identified missing `libxcb.so.1` and `libxkbcommon.so.0`; after adding those packages, `ldd` resolved the app's direct shared libraries and the launcher and desktop entry were present.
