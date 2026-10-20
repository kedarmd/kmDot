return {
	"catppuccin/nvim",
	name = "catppuccin",
	-- opts = {
	-- 	transparent_background = true,
	-- }
	config = function()
		vim.cmd.colorscheme("catppuccin")
	end,
}
