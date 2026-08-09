-- Main mod key
local mod = "SUPER"

-----------------
-- Keybindings   --
-----------------

-- Apps
hl.bind(mod .. " + RETURN", hl.dsp.exec_cmd("/usr/bin/ghostty"))
hl.bind(mod .. " + B", hl.dsp.exec_cmd("zen-browser"))
hl.bind(mod .. " + F", hl.dsp.exec_cmd("/usr/bin/nautilus"))
hl.bind(mod .. " + SPACE", hl.dsp.exec_cmd("rofi -show drun"))
hl.bind(mod .. " + T", hl.dsp.exec_cmd("bash -lc '$HOME/.config/kmdot/rofi/menu/theme-switcher.sh'"))
hl.bind(mod .. " + W", hl.dsp.window.close())
hl.bind(mod .. " + SHIFT + E", hl.dsp.exit())
hl.bind(mod .. " + L", hl.dsp.exec_cmd("hyprlock"))
hl.bind(mod .. " + ESCAPE", hl.dsp.exec_cmd("bash -c '$HOME/.config/kmdot/rofi/menu/system.sh'"))
hl.bind(mod .. " + R", hl.dsp.exec_cmd("bash -c '$HOME/.config/kmdot/waybar/scripts/launch.sh'"))
hl.bind(mod .. " + K", hl.dsp.exec_cmd("bash -lc '$HOME/.config/kmdot/rofi/menu/kmdot.sh'"))

-- Focus with arrow keys
hl.bind(mod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mod .. " + down", hl.dsp.focus({ direction = "down" }))

-- Move windows with Shift + arrows
hl.bind(mod .. " + SHIFT + left", hl.dsp.window.move({ direction = "left" }))
hl.bind(mod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
hl.bind(mod .. " + SHIFT + up", hl.dsp.window.move({ direction = "up" }))
hl.bind(mod .. " + SHIFT + down", hl.dsp.window.move({ direction = "down" }))

-- Resize with Ctrl + arrows
hl.bind(mod .. " + CTRL + left", hl.dsp.window.resize({ x = -20, y = 0, relative = true }))
hl.bind(mod .. " + CTRL + right", hl.dsp.window.resize({ x = 20, y = 0, relative = true }))
hl.bind(mod .. " + CTRL + up", hl.dsp.window.resize({ x = 0, y = -20, relative = true }))
hl.bind(mod .. " + CTRL + down", hl.dsp.window.resize({ x = 0, y = 20, relative = true }))

-- Layout controls
hl.bind(mod .. " + S", hl.dsp.layout("swaporientation"))
hl.bind(mod .. " + M", hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind(mod .. " + SHIFT + M", hl.dsp.window.fullscreen({ mode = "fullscreen" }))

-- Switch to workspace
for i = 1, 5 do
	hl.bind(mod .. " + " .. i, hl.dsp.focus({ workspace = i }))
end

-- Move focused window to workspace
for i = 1, 5 do
	hl.bind(mod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end

-- Toggle floating on the focused window
hl.bind(mod .. " + G", hl.dsp.window.float({ action = "toggle" }))

-- Mouse: move window when holding Super + Left Click
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
-- Mouse: resize window when holding Super + Right Click
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Brightness controls (no modifiers, just Fn keys -> XF86 keys)
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set +5% >/dev/null 2>&1"))
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%- >/dev/null 2>&1"))

-- Volume controls with 100% cap and wob support
hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd(
		"pactl set-sink-volume @DEFAULT_SINK@ +5%; [ $(pactl get-sink-volume @DEFAULT_SINK@ | grep -Po '\\d+(?=%)' | head -n 1) -gt 100 ] && pactl set-sink-volume @DEFAULT_SINK@ 100%"
	),
	{ repeating = true }
)
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("pactl set-sink-volume @DEFAULT_SINK@ -5%"), { repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("pactl set-sink-mute @DEFAULT_SINK@ toggle"))

-- Screenshots
hl.bind(mod .. " + PRINT", hl.dsp.exec_cmd("hyprshot -m window"))
hl.bind(mod .. " + SHIFT + PRINT", hl.dsp.exec_cmd("hyprshot -m output"))
hl.bind("PRINT", hl.dsp.exec_cmd("hyprshot -m region"))

-- Custom scripts
hl.bind(mod .. " + J", hl.dsp.layout("togglesplit"))
hl.bind("SUPER + CTRL + SPACE", hl.dsp.exec_cmd("~/.config/kmdot/hyprland/scripts/cycle_wallpapers.sh"))
