-- Main mod key
local mod = "SUPER"

-----------------
-- Keybindings   --
-----------------

-- Apps
hl.bind(mod .. " + RETURN", hl.dsp.exec_cmd("/usr/bin/ghostty")) -- Launch ghostty
hl.bind(mod .. " + B", hl.dsp.exec_cmd("zen-browser")) -- Open Zen browser
hl.bind(mod .. " + F", hl.dsp.exec_cmd("/usr/bin/nautilus")) -- Open file manager
hl.bind(mod .. " + SPACE", hl.dsp.exec_cmd("bash -c '$HOME/.config/kmdot/quickshell/scripts/launcher.sh'")) -- Application launcher (quickshell)
hl.bind(mod .. " + T", hl.dsp.exec_cmd("bash -c '$HOME/.config/kmdot/quickshell/scripts/toggle.sh kmdot-theme'")) -- Theme switcher (quickshell)
hl.bind(mod .. " + V", hl.dsp.exec_cmd("bash -c '$HOME/.config/kmdot/quickshell/scripts/toggle.sh kmdot-clipboard'")) -- Clipboard history (quickshell)
hl.bind(mod .. " + W", hl.dsp.window.close()) -- Close window
hl.bind(mod .. " + SHIFT + E", hl.dsp.exit()) -- Exit Hyprland
hl.bind(mod .. " + L", hl.dsp.exec_cmd("hyprlock")) -- Lock screen
hl.bind(mod .. " + ESCAPE", hl.dsp.exec_cmd("bash -c '$HOME/.config/kmdot/quickshell/scripts/toggle.sh kmdot-system'")) -- System menu (quickshell)
hl.bind(mod .. " + K", hl.dsp.exec_cmd("bash -c '$HOME/.config/kmdot/quickshell/scripts/toggle.sh kmdot-kmdot'")) -- kmDot menu (quickshell)

-- Focus with arrow keys
hl.bind(mod .. " + left", hl.dsp.focus({ direction = "left" })) -- Focus window left
hl.bind(mod .. " + right", hl.dsp.focus({ direction = "right" })) -- Focus window right
hl.bind(mod .. " + up", hl.dsp.focus({ direction = "up" })) -- Focus window up
hl.bind(mod .. " + down", hl.dsp.focus({ direction = "down" })) -- Focus window down

-- Move windows with Shift + arrows
hl.bind(mod .. " + SHIFT + left", hl.dsp.window.move({ direction = "left" })) -- Move window left
hl.bind(mod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" })) -- Move window right
hl.bind(mod .. " + SHIFT + up", hl.dsp.window.move({ direction = "up" })) -- Move window up
hl.bind(mod .. " + SHIFT + down", hl.dsp.window.move({ direction = "down" })) -- Move window down

-- Resize with Ctrl + arrows
hl.bind(mod .. " + CTRL + left", hl.dsp.window.resize({ x = -20, y = 0, relative = true })) -- Resize window left
hl.bind(mod .. " + CTRL + right", hl.dsp.window.resize({ x = 20, y = 0, relative = true })) -- Resize window right
hl.bind(mod .. " + CTRL + up", hl.dsp.window.resize({ x = 0, y = -20, relative = true })) -- Resize window up
hl.bind(mod .. " + CTRL + down", hl.dsp.window.resize({ x = 0, y = 20, relative = true })) -- Resize window down

-- Layout controls
hl.bind(mod .. " + M", hl.dsp.window.fullscreen({ mode = "maximized" })) -- Maximize window
hl.bind(mod .. " + SHIFT + M", hl.dsp.window.fullscreen({ mode = "fullscreen" })) -- Fullscreen window

-- Switch to workspace
for i = 1, 5 do
	hl.bind(mod .. " + " .. i, hl.dsp.focus({ workspace = i })) -- Switch to workspace
end

-- Move focused window to workspace
for i = 1, 5 do
	hl.bind(mod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i })) -- Move window to workspace
end

-- Toggle floating on the focused window
hl.bind(mod .. " + G", hl.dsp.window.float({ action = "toggle" })) -- Toggle floating window

-- Mouse: move window when holding Super + Left Click
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true }) -- Drag window with mouse
-- Mouse: resize window when holding Super + Right Click
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true }) -- Resize window with mouse

-- Brightness controls (no modifiers, just Fn keys -> XF86 keys)
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set +5% >/dev/null 2>&1")) -- Increase brightness
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%- >/dev/null 2>&1")) -- Decrease brightness

-- Volume controls with 100% cap and wob support
hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd(
		"pactl set-sink-volume @DEFAULT_SINK@ +5%; [ $(pactl get-sink-volume @DEFAULT_SINK@ | grep -Po '\\d+(?=%)' | head -n 1) -gt 100 ] && pactl set-sink-volume @DEFAULT_SINK@ 100%"
	),
	{ repeating = true }
) -- Raise volume
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("pactl set-sink-volume @DEFAULT_SINK@ -5%"), { repeating = true }) -- Lower volume
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("pactl set-sink-mute @DEFAULT_SINK@ toggle")) -- Mute volume

-- Screenshots
hl.bind(mod .. " + PRINT", hl.dsp.exec_cmd("hyprshot -m window")) -- Screenshot window
hl.bind(mod .. " + SHIFT + PRINT", hl.dsp.exec_cmd("hyprshot -m output")) -- Screenshot monitor
hl.bind("PRINT", hl.dsp.exec_cmd("hyprshot -m region")) -- Screenshot region

-- Custom scripts
hl.bind(mod .. " + J", hl.dsp.layout("togglesplit")) -- Toggle split layout
hl.bind("SUPER + CTRL + SPACE", hl.dsp.exec_cmd("~/.config/kmdot/hyprland/scripts/cycle_wallpapers.sh")) -- Cycle wallpapers

hl.bind(
	mod .. " + I",
	hl.dsp.exec_cmd("~/.config/kmdot/hyprland/scripts/toggle_handy.sh")
) -- Toggle Handy transcription window (launch hidden if not running, else toggle)
