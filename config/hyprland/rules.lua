-- Window rules

-- Make rofi float
hl.window_rule({
	match = { class = "rofi" },
	float = true,
})

-- Transcription window of Handy: float, pin, never steal focus, no border/blur
hl.window_rule({
	match = { class = "^(Handy)$", title = "^(Recording)$" },
	float = true,
	pin = true,
	no_focus = true,
	border_size = 0,
	no_blur = true,
})

-- Reposition Handy transcription window to bottom-center once fully mapped
hl.on("window.open", function(win)
	if win.title ~= "Recording" then
		return
	end
	local m = win.monitor or hl.get_active_monitor()
	if not m then
		return
	end
	hl.timer(function()
		hl.dispatch(hl.dsp.window.move({
			x = math.floor((m.width - win.size.x) / 2),
			y = m.height - win.size.y,
			window = "address:" .. win.address,
		}))
	end, { timeout = 1500, type = "oneshot" })
end)
