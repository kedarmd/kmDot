-- Window rules

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
		-- movewindow takes logical (layout) pixels but monitor geometry is
		-- physical: divide by scale (e.g. 1.25 on eDP-1) or the overlay
		-- lands below the visible area. Include the monitor origin so it
		-- centers on the right monitor in multi-monitor setups.
		local scale = m.scale or 1
		if scale == 0 then
			scale = 1
		end
		local mx = m.x or 0
		local my = m.y or 0
		hl.dispatch(hl.dsp.window.move({
			x = math.floor(mx + (m.width / scale - win.size.x) / 2),
			y = math.floor(my + m.height / scale - win.size.y),
			window = "address:" .. win.address,
		}))
	end, { timeout = 1500, type = "oneshot" })
end)
