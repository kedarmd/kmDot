# Install Arch Linux and kmDot on a laptop

This is the hands-on guide for installing Arch Linux on a physical laptop, then installing kmDot from GitHub. Follow it top to bottom. The separate [VM validation record](../testing/fresh-arch-vm-2026-11-23.md) contains the agent testing details.

## 1. Prepare the laptop and USB installer

Back up files you need from CachyOS before starting. The installation below erases the selected internal drive and replaces the current OS; it does not preserve CachyOS or set up dual boot. Keep the laptop connected to power.

Download the official x86_64 Arch ISO and its matching checksum/signature from [archlinux.org/download](https://archlinux.org/download/). Verify the ISO against the checksum for that exact release.

Check the downloaded file's SHA-256 with `sha256sum "$HOME/Downloads/archlinux-x86_64.iso"` and compare it with the checksum shown for that exact release.

Plug in a USB drive (8 GiB or larger is sufficient). Identify it carefully:

```bash
lsblk -o NAME,SIZE,MODEL,TRAN,TYPE,MOUNTPOINTS
```

Unmount any mounted partitions shown beneath the USB in `lsblk` (for example, `sudo umount /dev/sdX1`). Then write the ISO to the **whole USB device**, not a partition. Replace `/dev/sdX` with the USB device shown by `lsblk` (for example `/dev/sdb`). This command erases the USB drive:

```bash
sudo dd bs=4M if="$HOME/Downloads/archlinux-x86_64.iso" of=/dev/sdX conv=fsync status=progress
sudo sync
```

This writes to the whole device, as described in the [ArchWiki USB installation media guide](https://wiki.archlinux.org/title/USB_flash_installation_medium).

Boot the laptop from that USB using its one-time boot menu. Select the UEFI entry for the USB. Arch's installation ISO does not support Secure Boot, so disable Secure Boot in firmware for this install. This kmDot path does not configure signed Secure Boot for the installed system; leave it disabled unless you set up a signed boot chain separately. See the [ArchWiki installation guide](https://wiki.archlinux.org/title/Installation_guide#Boot_the_live_environment).

## 2. Connect to the internet and identify the internal drive

In the live Arch environment, set the keyboard layout:

```bash
loadkeys us
```

Ethernet with DHCP should connect automatically. For Wi-Fi, enter `iwctl`, find the wireless device, scan, list networks, and connect. Replace `wlan0` with the device name shown by `device list`:

```text
iwctl
[iwd]# device list
[iwd]# station wlan0 scan
[iwd]# station wlan0 get-networks
[iwd]# station wlan0 connect YOUR_WIFI_NAME
[iwd]# exit
```

Confirm network and time before installing:

```bash
ping -c 3 ping.archlinux.org
timedatectl
```

Identify the laptop's internal drive by model and size:

```bash
lsblk -o NAME,SIZE,MODEL,TRAN,TYPE,FSTYPE,MOUNTPOINTS
```

On many laptops the drive is `/dev/nvme0n1`; SATA drives often appear as `/dev/sda`. Do not assume the USB or internal-drive name. The partition commands below erase the entire selected internal drive. Check the model and capacity again before running them.

## 3. Partition and mount the internal drive

This guide uses GPT with a 1 GiB EFI System Partition and an ext4 root partition using the remaining space. It uses no swap partition and no disk encryption.

Set `DISK` to the internal drive you identified. This shell block handles the partition-name difference between NVMe/MMC drives and SATA drives:

```bash
DISK=/dev/nvme0n1 # change this to the internal drive from lsblk
case "$DISK" in
  *nvme*|*mmcblk*) EFI="${DISK}p1"; ROOT="${DISK}p2" ;;
  *) EFI="${DISK}1"; ROOT="${DISK}2" ;;
esac
printf 'About to erase %s and create %s + %s\n' "$DISK" "$EFI" "$ROOT"
```

Read the printed drive name and verify it against `lsblk`. Then partition and format it:

```bash
wipefs -af "$DISK"
sgdisk --zap-all "$DISK"
sgdisk --new=1:0:+1G --typecode=1:EF00 --change-name=1:EFI "$DISK"
sgdisk --new=2:0:0 --typecode=2:8300 --change-name=2:ArchRoot "$DISK"
partprobe "$DISK"
mkfs.fat -F32 "$EFI"
mkfs.ext4 -F "$ROOT"
mkdir -p /mnt/archinstall/boot
mount "$ROOT" /mnt/archinstall
mount "$EFI" /mnt/archinstall/boot
```

## 4. Install the Arch base system

Archinstall installs the base system. The tested setup selects the `linux` kernel and these additional packages:

```text
base-devel curl git jq networkmanager openssh sudo vim
```

No graphical desktop, browser, AUR helper, or AUR package is installed at this stage. The kmDot scripts install the workstation packages and apps after Arch boots.

Create `/tmp/config.json` in the live environment by starting `cat > /tmp/config.json <<'EOF'`, pasting this complete JSON, then entering `EOF` on its own line. Change the hostname if desired; leave the other values as shown to follow the tested path:

```bash
cat > /tmp/config.json <<'EOF'
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
  "hostname": "arch-kmdot",
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
EOF
```

Create `/tmp/creds.json` with your login user. The following opens Bash, asks for the username, and prompts for a password twice to generate its hash. Use that same password to sign in and for sudo. It does not print or save the password itself:

```bash
bash
read -r -p 'Login username: ' USERNAME
PASSWORD_HASH="$(openssl passwd -6)"
cat > /tmp/creds.json <<EOF
{
  "users": [
    {"username": "${USERNAME}", "sudo": true, "enc_password": "${PASSWORD_HASH}"}
  ]
}
EOF
unset PASSWORD_HASH
```

Then run the Arch installer:

```bash
archinstall --config /tmp/config.json --creds /tmp/creds.json --silent
```

When Archinstall completes, reboot and remove the USB. Sign in with the user you created, then confirm sudo works:

```bash
sudo -v
```

## 5. Clone kmDot and run its install scripts

Reconnect to Wi-Fi after boot if needed. Then clone kmDot and run the package installer followed by the config installer:

```bash
git clone https://github.com/kedarmd/kmDot.git
cd kmDot
./install.sh --all
./config-install.sh --all
```

`install.sh --all` installs packages from official Arch repositories and approved upstream sources. It bootstraps gum, mise, and Node.js 24; installs the apps; and generates `en_IN.UTF-8`. `config-install.sh --all` deploys the configs, enables SDDM and required services, changes the login shell to Fish, clones TPM for tmux, and applies Tokyo Night. No AUR helper or AUR package is used.

Reboot after both scripts complete. At SDDM, choose the Hyprland session if it is not already selected, then sign in. A Fish warning that `~/.config/fish/secrets.fish` is absent is expected: that private file is gitignored and the warning does not block setup.

## 6. Verify the installed setup

Open a terminal in Hyprland and run:

```bash
cd ~/kmDot
./tests/fresh-arch-smoke.sh
```

The tested result was **21 passed, 0 failed**. It checks the desktop session and configs, apps including Codex, Pi, Herdr App, Zen Browser, Handy, and Hex, Handy as the default dictation provider, SDDM, NetworkManager, locale generation, and that no foreign/AUR packages are installed.

Handy is the default dictation app. Hex is installed as the alternate provider. Hex's CLI is installed by the scripts; its speech model is a separate first-run download:

```bash
~/.local/bin/hex model install
```

## Troubleshooting and notes

### Pacman mirror timeout

If a package transfer in the live ISO stops because it falls below pacman's low-speed timeout, add `DisableDownloadTimeout` under `[options]` in `/etc/pacman.conf` and retry:

```bash
sed -i '/^\[options\]/a DisableDownloadTimeout' /etc/pacman.conf
```

### Package and download notes

- Hex's official Linux installer verifies its signed release. The `install.sh` dependency list includes its documented runtime libraries and Wayland paste helpers, including `openblas` and `wtype`, from official Arch repositories. See [Hex's Linux install documentation](https://github.com/anomalyco/hex/blob/dev/docs/linux.md#install-a-published-build).
- Herdr App is installed through [Herdr's official installer](https://herdr.dev/download/). The installer includes `libxcb` and `libxkbcommon`, which its app binary needs.
- Zen Browser is installed from the pinned, checksum-verified upstream tarball in `install.sh`; Firefox is not required. Zen's [official Linux guide](https://docs.zen-browser.app/guides/install-linux) also offers an AppImage, which was not the route tested.
- The Arch package set and some upstream applications are large downloads. Hex's speech model is a separate first-run download. Allow time for downloads to finish before interrupting an installer.
- After installation, check Wi-Fi, Bluetooth, microphone input, audio output, display brightness, suspend, and resume on the laptop.

## Internal VM validation reference

The exact agent-run VM choices, ISO checksum, earlier Herdr App investigation, and smoke-test record remain in [the VM validation notes](../testing/fresh-arch-vm-2026-11-23.md). Those notes are not the laptop installation procedure.
