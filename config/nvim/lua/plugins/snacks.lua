return {
	"folke/snacks.nvim",
	priority = 1000,
	lazy = false,
	---@type snacks.Config
	opts = {
		bigfile = { enabled = true },
		dashboard = {
			preset = {
				header = [[
██╗               ██████╗             ██╗   
██║               ██╔══██╗            ██║   
██║  ██╗███╗███╗  ██║  ██║ ██████╗ ████████╗
█████╔╝ ██╔██╔██╗ ██║  ██║██╔═══██╗╚═██╔══╝ 
██╔═██╗ ██║██║██║ ██████╔╝██║   ██║  ██║    
██║  ██╗██║╚═╝██║ ╚═════╝ ╚██████╔╝  ╚██╗   
╚═╝  ╚═╝╚═╝   ╚═╝          ╚═════╝    ╚═╝   ]],
			},
		},
		terminal = {
			win = { style = "terminal" },
		},
		image = { enabled = true }, -- Enabled for your Ghostty setup
		indent = { enabled = true },
		input = { enabled = true }, -- Fixed: This resolves the vim.ui.input warnings
		picker = { enabled = true }, -- Fixed: This resolves the vim.ui.select errors
		notifier = { enabled = true },
		lazygit = { enabled = true },
		explorer = { enabled = true },
		-- Keep these disabled if you don't use them, but enabled is recommended for full features
		quickfile = { enabled = true },
		scope = { enabled = false },
		scroll = { enabled = false },
		statuscolumn = { enabled = false },
		words = { enabled = false },
	},
	keys = {
		-- Explorer & Git
		{
			"\\",
			function()
				Snacks.picker.explorer()
			end,
			desc = "Explorer",
		},
		{
			"<leader>lg",
			function()
				Snacks.lazygit()
			end,
			desc = "Lazygit",
		},

		-- Terminal (Normal & Terminal mode)
		{
			"<C-`>",
			function()
				Snacks.terminal.toggle()
			end,
			desc = "Toggle Terminal",
		},
		{
			"<C-`>",
			function()
				Snacks.terminal.toggle()
			end,
			desc = "Toggle Terminal",
			mode = "t",
		},

		-- Picker / Search
		{
			"<leader>sf",
			function()
				Snacks.picker.files()
			end,
			desc = "[S]earch [F]iles",
		},
		{
			"<leader><leader>",
			function()
				Snacks.picker.buffers()
			end,
			desc = "[Search] [Buffers]",
		},
		{
			"<leader>sw",
			function()
				Snacks.picker.grep_word()
			end,
			desc = "[Search] current [W]ord",
		},
		{
			"<leader>sg",
			function()
				if vim.fn.executable("rg") ~= 1 then
					vim.notify("Repository search requires ripgrep (rg).", vim.log.levels.WARN)
					return
				end

				local cwd = vim.fn.getcwd()
				Snacks.picker.grep({ cwd = vim.fs.root(0, ".git") or vim.fs.root(cwd, ".git") or cwd })
			end,
			desc = "[Search] repository by [G]rep",
		},
		{
			"<leader>sd",
			function()
				Snacks.picker.diagnostics()
			end,
			desc = "[Search] [D]iagnostics",
		},
		{
			"<leader>sr",
			function()
				Snacks.picker.resume()
			end,
			desc = "[Search] [R]esume",
		},
		{
			"<leader>sb",
			function()
				Snacks.picker.git_branches()
			end,
			desc = "[Search] [B]ranches",
		},
	},
}
