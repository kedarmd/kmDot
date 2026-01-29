return {
	"sainnhe/everforest",
	config = function()
		-- Use dark background for terminal/editor
		vim.opt.background = "dark"

		-- Load the colorscheme
		vim.cmd.colorscheme("everforest")
	end,
}
