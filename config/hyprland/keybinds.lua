-- Main mod key
local mod = "SUPER"

-----------------
-- Keybindings   --
-----------------

-- Apps
hl.bind(mod .. " + RETURN", hl.dsp.exec_cmd("/usr/bin/ghostty")) -- Launch ghostty
hl.bind(
	mod .. " + SHIFT + RETURN",
	hl.dsp.exec_cmd("/usr/bin/ghostty -e bash -c 'herdr workspace create --focus 2>/dev/null; exec herdr'")
) -- Launch ghostty with a new herdr workspace
hl.bind(mod .. " + B", hl.dsp.exec_cmd("zen-browser")) -- Open Zen browser
hl.bind(mod .. " + F", hl.dsp.exec_cmd("/usr/bin/nautilus")) -- Open file manager
hl.bind(mod .. " + SPACE", hl.dsp.exec_cmd("bash -c '$HOME/.config/kmdot/quickshell/scripts/launcher.sh'")) -- Application launcher (quickshell)
hl.bind(mod .. " + T", hl.dsp.exec_cmd("bash -c '$HOME/.config/kmdot/quickshell/scripts/toggle.sh kmdot-theme'")) -- Theme switcher (quickshell)
 hl.bind(mod .. " + V", hl.dsp.exec_cmd("bash -c '$HOME/.config/kmdot/quickshell/scripts/toggle.sh kmdot-clipboard'")) -- Clipboard history (quickshell)

hl.bind(mod .. " + H", hl.dsp.exec_cmd("bash -c '$HOME/.config/kmdot/quickshell/scripts/toggle.sh kmdot-handy-launcher'")) -- Handy launcher (quickshell)
hl.bind(mod .. " + W", hl.dsp.window.close()) -- Close window
hl.bind(mod .. " + SHIFT + E", hl.dsp.exit()) -- Exit Hyprland
hl.bind(mod .. " + L", hl.dsp.exec_cmd("~/.config/kmdot/quickshell/scripts/lock-screen.sh")) -- Lock screen
hl.bind(mod .. " + ESCAPE", hl.dsp.exec_cmd("bash -c '$HOME/.config/kmdot/quickshell/scripts/toggle.sh kmdot-system'")) -- System menu (quickshell)
hl.bind(mod .. " + K", hl.dsp.exec_cmd("bash -c '$HOME/.config/kmdot/quickshell/scripts/toggle.sh kmdot-kmdot'")) -- kmDot menu (quickshell)

-- Notification controls (Quickshell IpcHandler)
hl.bind(mod .. " + N", hl.dsp.exec_cmd("qs ipc call notifications togglePanel")) -- Toggle notification center
hl.bind(mod .. " + SHIFT + N", hl.dsp.exec_cmd("qs ipc call notifications toggleDnd")) -- Toggle Do Not Disturb

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

-- Brightness controls (laptop media keys -> XF86 keys)
local brightnessUp = hl.dsp.exec_cmd("qs ipc call displayBrightness increase; ~/.config/quickshell/scripts/toggle.sh kmdot-osd-brightness")
local brightnessDown = hl.dsp.exec_cmd("qs ipc call displayBrightness decrease; ~/.config/quickshell/scripts/toggle.sh kmdot-osd-brightness")
hl.bind("XF86MonBrightnessUp", brightnessUp, { repeating = true }) -- Increase brightness (media keys)
hl.bind("XF86MonBrightnessDown", brightnessDown, { repeating = true }) -- Decrease brightness (media keys)

-- Volume controls with 100% cap and wob support
hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd(
		"pactl set-sink-volume @DEFAULT_SINK@ +5%; [ $(pactl get-sink-volume @DEFAULT_SINK@ | grep -Po '\\d+(?=%)' | head -n 1) -gt 100 ] && pactl set-sink-volume @DEFAULT_SINK@ 100%; ~/.config/quickshell/scripts/toggle.sh kmdot-osd-volume"
	),
	{ repeating = true }
) -- Raise volume
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("pactl set-sink-volume @DEFAULT_SINK@ -5%; ~/.config/quickshell/scripts/toggle.sh kmdot-osd-volume"), { repeating = true }) -- Lower volume
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("pactl set-sink-mute @DEFAULT_SINK@ toggle; ~/.config/quickshell/scripts/toggle.sh kmdot-osd-volume")) -- Mute volume
local micMuteAction = hl.dsp.exec_cmd("pactl set-source-mute @DEFAULT_SOURCE@ toggle; ~/.config/quickshell/scripts/toggle.sh kmdot-osd-mic")
hl.bind("XF86AudioMicMute", micMuteAction) -- Toggle microphone mute
hl.bind("F4", micMuteAction, { repeating = false }) -- Laptop mic key can report F4, including its Fn layer

-- Media controls
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause")) -- Play/pause media
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause")) -- Pause media
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next")) -- Next track
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous")) -- Previous track

-- Screenshots
hl.bind(mod .. " + PRINT", hl.dsp.exec_cmd("hyprshot -m window")) -- Screenshot window
hl.bind(mod .. " + SHIFT + PRINT", hl.dsp.exec_cmd("hyprshot -m output")) -- Screenshot monitor
hl.bind("PRINT", hl.dsp.exec_cmd("hyprshot -m region")) -- Screenshot region

-- Custom scripts
hl.bind(mod .. " + J", hl.dsp.layout("togglesplit")) -- Toggle split layout
hl.bind("SUPER + CTRL + SPACE", hl.dsp.exec_cmd("bash -c '$HOME/.config/kmdot/quickshell/scripts/toggle.sh kmdot-wallpaper'")) -- Wallpaper switcher (quickshell)

hl.bind(
	mod .. " + I",
	hl.dsp.exec_cmd("~/.config/kmdot/hyprland/scripts/toggle_handy.sh")
) -- Toggle Handy transcription: start; while recording Enter submits, Escape cancels
