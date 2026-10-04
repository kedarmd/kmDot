-- Environment variables (loaded before autostart)
hl.env("ADW_COLOR_SCHEME", "prefer-dark")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")

-- Screenshots: hyprshot has no config file (v1.3.0 reads only HYPRSHOT_DIR /
-- XDG_PICTURES_DIR, no -o in the keybinds), so it defaults to ~/Pictures.
-- This keeps every compositor-spawned hyprshot (the PRINT binds, and anything
-- launched from the launcher) in ~/Pictures/Screenshots. hyprshot mkdir -p's
-- the folder itself.
hl.env("HYPRSHOT_DIR", os.getenv("HOME") .. "/Pictures/Screenshots")

-- mise shims + user bin first: GUI-launched quickshell never sources a shell
-- rc, so this is what puts mise Node (and npm globals like opencode) on PATH
-- for quickshell, keybind-spawned toggle.sh (node -e) and #!/usr/bin/env node
-- scripts. install.sh pins node globally (`mise use -g node@24`) so the shims
-- resolve outside the repo too.
hl.env("PATH", os.getenv("HOME") .. "/.local/share/mise/shims:" .. os.getenv("HOME") .. "/.local/bin:" .. (os.getenv("PATH") or ""))

-- Export env vars to systemd user services (portals, etc.)
hl.on("hyprland.start", function()
    hl.exec_cmd("dbus-update-activation-environment --systemd --all")
end)
