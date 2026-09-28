return {
	"williamboman/mason.nvim",
	dependencies = {
		"WhoIsSethDaniel/mason-tool-installer.nvim",
		{ "j-hui/fidget.nvim", opts = {} },
	},
	config = function()
		-- 1. Initialize Mason FIRST so it adds downloaded binaries (like ts_ls) to your $PATH
		require("mason").setup()

		-- 2. Set up blink.cmp capabilities
		local capabilities = require("blink.cmp").get_lsp_capabilities()

		-- 3. Define servers using the Native 0.12 syntax
		local servers = {
			ts_ls = {
				cmd = { "typescript-language-server", "--stdio" },
				filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
				capabilities = capabilities,
				root_markers = { "package.json", "tsconfig.json", ".git" },
			},
			gopls = {
				cmd = { "gopls" },
				filetypes = { "go", "gomod", "gowork", "gotmpl" },
				capabilities = capabilities,
				root_markers = { "go.work", "go.mod", ".git" },
			},
			lua_ls = {
				cmd = { "lua-language-server" },
				filetypes = { "lua" },
				-- Added root markers for Lua so it knows where the project root is
				root_markers = { ".luarc.json", ".stylua.toml", "init.lua", ".git" },
				capabilities = capabilities,
				settings = {
					Lua = {
						completion = { callSnippet = "Replace" },
					},
				},
			},
		}

		-- 4. Auto-install tools via Mason
		-- We must use Mason's specific package names here, not Neovim's LSP names
		local ensure_installed = {
			"typescript-language-server", -- Mason's name for ts_ls
			"gopls", -- Mason's name for gopls
			"lua-language-server", -- Mason's name for lua_ls
			"stylua", -- Your Lua formatter
		}
		require("mason-tool-installer").setup({ ensure_installed = ensure_installed })

		-- 5. Configure Diagnostics Visually
		vim.diagnostic.config({
			signs = {
				text = {
					[vim.diagnostic.severity.ERROR] = " ",
					[vim.diagnostic.severity.WARN] = " ",
					[vim.diagnostic.severity.HINT] = "󰠠 ",
					[vim.diagnostic.severity.INFO] = " ",
				},
			},
			virtual_text = { prefix = "●", spacing = 4 },
			underline = true,
			update_in_insert = false,
			severity_sort = true,
		})

		-- 6. Single owner for LSP attachment behavior (mappings + highlight lifecycle)
		local highlight_augroup = vim.api.nvim_create_augroup("lsp-highlight", { clear = false })
		vim.api.nvim_create_autocmd("LspDetach", {
			group = vim.api.nvim_create_augroup("lsp-detach", { clear = true }),
			callback = function(event)
				-- LspDetach fires before the client detaches, so exclude it when
				-- checking whether any remaining client still needs highlights.
				local remaining = vim.tbl_filter(function(c)
					return c.id ~= event.data.client_id
						and c:supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight)
				end, vim.lsp.get_clients({ bufnr = event.buf }))
				if #remaining == 0 then
					vim.lsp.buf.clear_references()
					vim.api.nvim_clear_autocmds({ group = highlight_augroup, buffer = event.buf })
				end
			end,
		})

		vim.api.nvim_create_autocmd("LspAttach", {
			group = vim.api.nvim_create_augroup("lsp-attach", { clear = true }),
			callback = function(event)
				local map = function(keys, func, desc, mode)
					mode = mode or "n"
					vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = "LSP: " .. desc })
				end

				-- Required here (not at startup) so this module stays loadable before Telescope.
				local builtin = require("telescope.builtin")
				map("gd", builtin.lsp_definitions, "[G]oto [D]efinition")
				map("gr", builtin.lsp_references, "[G]oto [R]eferences")
				map("gI", builtin.lsp_implementations, "[G]oto [I]mplementation")
				map("<leader>D", builtin.lsp_type_definitions, "Type [D]efinition")
				map("<leader>ds", builtin.lsp_document_symbols, "[D]ocument [S]ymbols")
				map("<leader>ws", builtin.lsp_dynamic_workspace_symbols, "[W]orkspace [S]ymbols")

				map("<leader>rn", vim.lsp.buf.rename, "[R]e[n]ame")
				map("<leader>ca", vim.lsp.buf.code_action, "[C]ode [A]ction", { "n", "x" })
				map("K", vim.lsp.buf.hover, "Hover Documentation")
				map("gD", vim.lsp.buf.declaration, "[G]oto [D]eclaration")

				local client = vim.lsp.get_client_by_id(event.data.client_id)
				if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight) then
					-- LspAttach fires once per client, so install once per buffer.
					if #vim.api.nvim_get_autocmds({ group = highlight_augroup, buffer = event.buf }) == 0 then
						vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
							buffer = event.buf,
							group = highlight_augroup,
							callback = vim.lsp.buf.document_highlight,
						})

						vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
							buffer = event.buf,
							group = highlight_augroup,
							callback = vim.lsp.buf.clear_references,
						})
					end
				end

				if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint) then
					map("<leader>th", function()
						vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = event.buf }))
					end, "[T]oggle Inlay [H]ints")
				end
			end,
		})

		-- 7. The Native 0.12 Engine Initialization
		for server_name, server_config in pairs(servers) do
			-- Pass your custom capabilities and root_markers into the native config
			vim.lsp.config(server_name, server_config)
			-- Enable the server globally using a string, not a table
			vim.lsp.enable(server_name)
		end
	end,
}
