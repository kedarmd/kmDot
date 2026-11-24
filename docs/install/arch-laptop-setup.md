# Install Arch Linux and kmDot on a laptop

This is the hands-on guide for replacing the current OS with Arch Linux on a physical laptop, then installing kmDot from GitHub. Follow the numbered steps in order. VM installation and validation notes are kept in a separate internal record.

## 1. Prepare the laptop and USB installer

Back up files you need from CachyOS. Keep the laptop connected to power. Download the official x86_64 Arch ISO and its matching checksum or signature from [archlinux.org/download](https://archlinux.org/download/) and verify the download for that release.

Use a USB writing app with a graphical interface, such as [balenaEtcher](https://etcher.balena.io/), to write the ISO to a USB drive. Select the ISO file and the USB device, then let the app verify the write. This erases the USB drive, so check the selected device carefully.

Boot the laptop from the USB using its one-time boot menu. Select its UEFI entry. Arch's installation ISO does not support Secure Boot. This setup does not configure signed Secure Boot for the installed system, so disable Secure Boot in firmware. See the [Arch Linux installation guide](https://wiki.archlinux.org/title/Installation_guide#Boot_the_live_environment).

## 2. Connect the live installer to the internet

Archinstall needs internet access to download Arch packages. Wired Ethernet usually connects automatically. For Wi-Fi, connect the live installer before starting Archinstall:

```text
iwctl
[iwd]# device list
[iwd]# station wlan0 scan
[iwd]# station wlan0 get-networks
[iwd]# station wlan0 connect YOUR_WIFI_NAME
[iwd]# exit
```

Replace `wlan0` with the wireless device name shown by `device list`. This is the only setup outside Archinstall that may be needed before the repository is cloned; the Arch ISO must already have a network connection before Archinstall can download the system. If the laptop has Ethernet or USB internet tethering available, use that to skip the Wi-Fi setup.

## 3. Install Arch with Archinstall

At the live installer prompt, run:

```bash
archinstall
```

Use Archinstall's menus to set the following values. Menu wording can shift between ISO releases; leave values at the defaults where the table says so.

| Archinstall setting | Choose |
|---|---|
| Language and locales | English; keyboard layout `us`; locale `en_US.UTF-8`; encoding `UTF-8` |
| Drive setup | Choose the automatic default layout. Select the laptop's internal drive, then confirm that Archinstall can erase it and use the entire drive for this Arch installation. Choose `ext4` as the main filesystem. Leave disk encryption off. |
| Swap | Leave disabled, matching the tested setup. |
| Bootloader | `Systemd-boot` (the default). |
| Kernel | `linux` (the default). |
| Hostname | Choose a name, for example `arch-kmdot`. |
| Authentication | Add your normal login user, set a password, and answer **Yes** when asked whether the user should have sudo privileges. A separate root password is not needed. |
| Profile and applications | Leave no desktop profile or extra applications selected. kmDot installs the desktop and apps later. |
| Network configuration | `Use Network Manager (default backend)`. |
| Additional packages | Add `base-devel`, `curl`, `git`, `jq`, `openssh`, `sudo`, and `vim`. `git` and `curl` are needed to clone and run kmDot after reboot. |
| Timezone | `Asia/Kolkata`. |
| Automatic time sync | Enabled. |

Leave mirror and pacman options at their defaults. Review the configuration shown by Archinstall, check the selected internal drive and the erase confirmation, then choose **Install**. Let it finish before rebooting. Remove the USB when the laptop restarts.

## 4. Clone kmDot and install the workstation

Sign in to the new Arch system using the user created in Archinstall. Open a terminal, clone the public repository, and run the two scripts in order:

```bash
git clone https://github.com/kedarmd/kmDot.git
cd kmDot
./install.sh --all
./config-install.sh --all
```

`install.sh --all` installs packages from official Arch repositories and approved upstream sources. It bootstraps gum, mise, and Node.js 24; installs the apps; and generates `en_IN.UTF-8`. `config-install.sh --all` deploys the configs, enables SDDM and required services, changes the login shell to Fish, clones TPM for tmux, and applies Tokyo Night. No AUR helper or AUR package is used.

Reboot after both scripts complete. At SDDM, choose the Hyprland session if it is not already selected, then sign in. A Fish warning that `~/.config/fish/secrets.fish` is absent is expected: that private file is gitignored and the warning does not block setup.

## 5. Verify the installed setup

Open a terminal in Hyprland and run:

```bash
cd ~/kmDot
./tests/fresh-arch-smoke.sh
```

The smoke check covers the desktop session and configs, apps including Codex, Pi, Herdr App, and Zen Browser, SDDM, NetworkManager, locale generation, and the absence of foreign/AUR packages.

## Troubleshooting and hardware checks

- If a package download stalls or times out in Archinstall, choose **Mirrors and repositories**, select a different nearby mirror, and retry the install.
- Herdr App is installed using [Herdr's official installer](https://herdr.dev/download/). Its installer includes the required `libxcb` and `libxkbcommon` libraries.
- Zen Browser is installed from the pinned, checksum-verified upstream tarball in `install.sh`; Firefox is not required. Zen's [official Linux guide](https://docs.zen-browser.app/guides/install-linux) also offers an AppImage, which was not the route tested.
- The Arch base and some upstream applications are large downloads. Let downloads finish before interrupting an installer.
- After installation, check Wi-Fi, Bluetooth, microphone input, audio output, display brightness, suspend, and resume on the laptop.

For optional pre-upgrade recovery on the ext4 layout above, see [Timeshift setup](timeshift-recovery.md).
