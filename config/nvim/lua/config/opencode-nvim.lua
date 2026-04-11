local M = {
	config = {
		keybind = "<C-\\>",
		direction = "vertical",
		size = 75,
		win_nav = true,
	},
}

function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})

	local function get_term_opts()
		local cwd = vim.fn.getcwd()
		local position = M.config.direction == "vertical" and "right" or "bottom"
		local size = M.config.direction == "vertical" and M.config.size or M.config.size

		local term_opts = {
			cwd = cwd,
			win = {
				style = "terminal",
				position = position,
			},
		}

		if M.config.direction == "vertical" then
			term_opts.win.width = size
		else
			term_opts.win.height = size
		end

		return term_opts
	end

	function M.toggle()
		local Snacks = require("snacks")
		local term_opts = get_term_opts()
		Snacks.terminal.toggle({ "opencode" }, term_opts)
	end

	vim.keymap.set("n", M.config.keybind, function()
		M.toggle()
	end, { desc = "Toggle opencode terminal" })

	vim.keymap.set("t", M.config.keybind, function()
		M.toggle()
	end, { desc = "Toggle opencode terminal" })

	if M.config.win_nav then
		local function nav(dir)
			local mode = vim.fn.mode()
			if mode == "t" then
				vim.cmd("stopinsert")
			end
			vim.cmd("wincmd " .. dir)
		end

		vim.keymap.set("t", "<C-h>", function()
			nav("h")
		end, { desc = "Navigate left" })
		vim.keymap.set("t", "<C-j>", function()
			nav("j")
		end, { desc = "Navigate down" })
		vim.keymap.set("t", "<C-k>", function()
			nav("k")
		end, { desc = "Navigate up" })
		vim.keymap.set("t", "<C-l>", function()
			nav("l")
		end, { desc = "Navigate right" })
	end
end

return M
