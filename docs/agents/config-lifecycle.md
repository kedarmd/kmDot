# Config lifecycle

## Sync and activation

1. Run the matching `sync/<app>.sh` and check its exit status. Compare the relevant repo file to its deployed copy or inspect the destination if sync generates it.
2. Activate the change in the desktop session. Quickshell disables source hot reload, so restart the running shell or start a new Hyprland session after syncing QML. Check the session is unlocked before restarting Quickshell. For Hyprland changes, use `hyprctl reload` and inspect `hyprctl configerrors`.
3. Verify through the normal entry point. Reopen the relevant popup or launch the app. For system appearance, check both the desktop preference and the setting apps receive:
   ```bash
   gsettings get org.gnome.desktop.interface color-scheme
   gdbus call --session --dest org.freedesktop.portal.Desktop \
     --object-path /org/freedesktop/portal/desktop \
     --method org.freedesktop.portal.Settings.Read org.freedesktop.appearance color-scheme
   ```
   The portal value `1` means prefer dark. Report disk deployment and live activation separately if the session is unavailable.

## Remove an app

- List affected files first with `rg -l` and narrow by exact app names, unit names, or socket names before reading matching lines.
- Remove package and config picker entries, sync and theme hooks, units and autostart entries, shortcuts, and UI references. Update smoke checks and current docs. Label retained historical reports.
- Stop units before removing their launch files. Inspect named app paths before deleting local data. For archived UI, use an inert file extension and remove all live entry points.
- Run `./scripts/check-config-references.sh`, then sync affected configs. The check covers config installer entries and quoted literal repo paths in sync scripts. Inspect variable paths and runtime behavior separately.

## Diagnose a missing window or crash

- Compare the app's command exit status with its user service journal (`journalctl --user -u <unit> -b`) and Hyprland's actual windows (`hyprctl clients -j`). A successful request can still fail to produce a window.
- For a graphics backend error, check the installed driver and device detection with `vulkaninfo --summary` if available.
- After a reboot, inspect the previous kernel journal with `journalctl -k -b -1`. If the log ends without a crash diagnostic, record the cause as unknown.
- Before replacing a recording overlay, identify how to observe actual start, stop, cancel, and completion events. Shortcut presses alone cannot establish those states.
