-- Aesthetics

hl.config({
	general = {
		gaps_in = 3,
		gaps_out = 6,
		border_size = 2,
		layout = "dwindle",
	},

	dwindle = {
		preserve_split = true,
	},

	decoration = {
		rounding = 8,
		active_opacity = 0.99,
		inactive_opacity = 0.95,

		blur = {
			enabled = true,
			size = 5,
			new_optimizations = true,
		},
	},

	animations = {
		enabled = true,
	},
})

-- Animations
hl.curve("fast", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.0 } } })

hl.animation({ leaf = "windows", enabled = true, speed = 5, bezier = "fast" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 5, bezier = "fast" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 3, bezier = "fast" })
hl.animation({ leaf = "border", enabled = true, speed = 3, bezier = "fast" })
hl.animation({ leaf = "fade", enabled = true, speed = 3, bezier = "fast" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "fast" })
