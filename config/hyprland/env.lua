-- Environment variables (loaded before autostart)
hl.env("ADW_COLOR_SCHEME", "prefer-dark")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")

-- Export env vars to systemd user services (portals, etc.)
hl.on("hyprland.start", function()
    hl.exec_cmd("dbus-update-activation-environment --systemd --all")
end)
