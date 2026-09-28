vim.cmd("set expandtab")
vim.cmd("set tabstop=2")
vim.cmd("set softtabstop=2")
vim.cmd("set shiftwidth=2")

vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Set to true if you have a Nerd Font installed
vim.g.have_nerd_font = true

-- Enable mouse mode, can be useful for resizing splits for example!
vim.opt.mouse = "a"

-- Decrease mapped sequence wait time
-- Displays which-key popup sooner
vim.opt.timeoutlen = 300

-- Show which line your cursor is on
vim.opt.cursorline = true

-- Minimal number of screen lines to keep above and below the cursor.
vim.opt.scrolloff = 10

-- Case-insensitive searching UNLESS \C or one or more capital letters in the search term
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Enable termguicolors colors
vim.opt.termguicolors = true

vim.opt.signcolumn = "yes"

vim.opt.cmdheight = 0

-- Enable nvim starting with server
local server_name = "/tmp/nvim-" .. vim.fn.getpid() .. ".sock"
vim.fn.serverstart(server_name)

-- Sync clipboard between OS and Neovim.
--  Schedule the setting after `UiEnter` because it can increase startup-time.
--  Remove this option if you want your OS clipboard to remain independent.
--  See `:help 'clipboard'`
-- vim.schedule(function()
-- end)
vim.opt.clipboard:append("unnamedplus")

-- Highlight when yanking (copying) text
--  Try it with `yap` in normal mode
--  See `:help vim.highlight.on_yank()`
vim.api.nvim_create_autocmd("TextYankPost", {
	desc = "Highlight when yanking (copying) text",
	group = vim.api.nvim_create_augroup("kickstart-highlight-yank", { clear = true }),
	callback = function()
		vim.highlight.on_yank()
	end,
})

local keymap = vim.keymap -- for conciseness

-- Move Selection up & down (copied from Primeagen's YouTube video)
keymap.set("v", "J", ":m'>+1<CR>gv=gv")
keymap.set("v", "K", ":m'<-2<CR>gv=gv")

-- window management
keymap.set("n", "<leader>sv", "<C-w>v", { desc = "Split window vertically" })
keymap.set("n", "<leader>sh", "<C-w>s", { desc = "Split window horizontally" })
keymap.set("n", "<leader>se", "<C-w>=", { desc = "Make splits equal size" })
keymap.set("n", "<leader>sx", "<cmd>close<CR>", { desc = "Close current split" })

vim.opt.number = true
local default_relative_line_value = true
vim.opt.relativenumber = default_relative_line_value
local function toggle_relative_number()
	vim.opt.relativenumber = not default_relative_line_value
	default_relative_line_value = vim.wo.relativenumber
end
keymap.set("n", "<leader>tl", toggle_relative_number, { desc = "[T]oggle relatived [L]ine Numbers" })

keymap.set("n", "<ESC>", ":nohl<CR>", { desc = "Clear search highlights" })

require("config.opencode-nvim").setup({})
