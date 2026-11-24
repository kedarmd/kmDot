# Pre-upgrade recovery on ext4 with Timeshift

Use Timeshift in RSYNC mode on an ext4 workstation. The km.launcher **System Upgrade** action uses a configured Snapper root snapshot when available and falls back to Timeshift. Both providers are optional. The terminal reports the result before opening Pacman's final transaction prompt.

## Configure each machine

The setup snippets use Bash. If your interactive shell is Fish, run `bash` first, then return to Fish with `exit` when setup is complete.

1. Identify the root, boot, and backup filesystems.

   ```bash
   lsblk -o NAME,FSTYPE,SIZE,UUID,MOUNTPOINTS
   findmnt --target /
   findmnt --target /boot
   bootctl status
   ```

   Choose an existing, mounted Linux filesystem with space for the initial copy of the system and later changes. An external ext4 drive mounted under `/mnt` or `/run/media` provides recovery if the system disk fails. A separate ext4 `/home` partition on the same disk can hold restore points for update failures. The launcher requires a mount path without spaces.

2. Install the official Arch packages on an up-to-date system.

   ```bash
   sudo pacman -S --needed timeshift jq rsync
   ```

3. From the kmDot checkout, install the tracked Timeshift defaults. Change `backup_mount` to your chosen mounted filesystem. The example uses `/home`, which is a separate ext4 partition on the laptop this guide was written for. If Timeshift is already configured, use its **Settings → Type → RSYNC** and **Settings → Location** instead to preserve existing settings.

   ```bash
   (
     set -euo pipefail
     backup_mount=/home
     backup_uuid=$(findmnt -nro UUID --mountpoint "$backup_mount")
     [[ -n "$backup_uuid" && "$backup_mount" != / ]]
     sudo -v
     if sudo test -e /etc/timeshift/timeshift.json || sudo test -e /etc/timeshift.json; then
       printf 'Timeshift already has settings. Update its type and location in Timeshift.\n' >&2
       exit 1
     fi
     config_tmp=$(mktemp)
     trap 'unlink "$config_tmp"' EXIT
     jq --arg uuid "$backup_uuid" '.backup_device_uuid = $uuid' \
       config/timeshift/timeshift.json >"$config_tmp"
     sudo install -Dm644 "$config_tmp" /etc/timeshift/timeshift.json
   )
   ```

   The repository tracks the provider defaults. Timeshift's native config holds the device UUID locally. The template uses on-demand backups and Timeshift's default exclusions for home data. Keep personal files backed up separately.

4. Sync the launcher and create a baseline restore point. This can be done even when Pacman has no pending updates.

   ```bash
   ./sync/quickshell.sh
   sudo timeshift --create --rsync --scripted --comments 'kmDot baseline'
   sudo timeshift --list --rsync
   ```

   Check that the baseline is listed. Copy its name and check its boot files. The comparison should print nothing and exit successfully.

   ```bash
   backup_mount=/home
   snapshot=YYYY-MM-DD_HH-MM-SS
   sudo rsync --recursive --links --checksum --dry-run --delete --itemize-changes \
     /boot/ "$backup_mount/timeshift/snapshots/$snapshot/localhost/boot/"
   ```

   Replace `YYYY-MM-DD_HH-MM-SS` with the exact name from the Timeshift list. The ext4 laptop's baseline `2026-11-24_07-20-08` passed this comparison with `/home` as the destination and a separate FAT `/boot` partition. A full restore on that laptop is still untested.

## Use and maintain restore points

Open **System Upgrade** from km.launcher and select **Proceed**. Press Enter at **Create a Timeshift restore point** to make a fresh backup before Pacman starts. The launcher checks that the new snapshot contains the Pacman database directory and compares its saved boot files with the live `/boot` tree. Wait for **Created Timeshift restore point … and verified /boot**, then note the snapshot name and review Pacman's final confirmation. A failed check returns to the backup prompt. Press `e` to exit if you need a verified recovery point, or `n` to explicitly skip the backup.

Keep a recent known-good point and enough space for the next backup. The launcher creates on-demand points. Use Timeshift's snapshot list to review and delete old on-demand points as needed.

## Recover after a failed upgrade

If the workstation still boots, run Timeshift from the installed system. If it cannot boot, start a live Linux environment with Timeshift available. Boot it in UEFI mode for a UEFI installation. Identify the original root and boot partitions and the backup device by UUID. In Timeshift's interactive restore, select the snapshot named by the upgrade terminal and review the destination mapping before confirming.

On a systemd-boot machine, skip GRUB installation. The command below selects the backup device by UUID and leaves the snapshot and targets interactive.

```bash
sudo timeshift --restore --rsync --snapshot-device BACKUP_UUID --skip-grub
```

Map the separate `/boot` partition to its original device. If there is also a separate `/boot/efi`, map it too. Make sure the matching kernel and initramfs (or UKI) and boot entries are present on the actual boot partition before rebooting. If Timeshift cannot map the boot partition, mount it explicitly from the live environment and recover its contents from the same snapshot's `localhost/boot/` tree. Practice the recovery on a spare system before relying on it.

[Timeshift upstream documentation](https://github.com/linuxmint/timeshift#system-restore) · [Arch Timeshift command reference](https://man.archlinux.org/man/extra/timeshift/timeshift.1.en)
