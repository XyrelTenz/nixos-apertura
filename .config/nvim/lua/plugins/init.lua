return {
	{
		"stevearc/conform.nvim",
		event = "BufWritePre",
		opts = require("configs.conform"),
	},
	{
		"NvChad/ui",
		lazy = false,
	},

	{
		"neovim/nvim-lspconfig",
		event = { "BufReadPost", "BufNewFile" },
		config = function()
			require("configs.lspconfig")
		end,
	},
	--- Nvim Tree
	{
		"nvim-tree/nvim-tree.lua",
		opts = {
			sync_root_with_cwd = true,
			respect_buf_cwd = true,
			update_focused_file = {
				enable = true,
				update_root = true,
			},
			prefer_startup_root = true,
			filters = {
				custom = { "node_modules", "target", "build", "dist", "out" },
				dotfiles = false,
			},
			on_attach = function(bufnr)
				local api = require("nvim-tree.api")
				local function opts(desc)
					return { desc = "nvim-tree: " .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
				end
				api.config.mappings.default_on_attach(bufnr)
				vim.keymap.set("n", "l", api.node.open.edit, opts("Open"))
				vim.keymap.set("n", "h", api.node.navigate.parent_close, opts("Close Directory"))
				vim.keymap.set("n", "<CR>", api.node.open.edit, opts("Open"))
			end,
			view = { adaptive_size = true, side = "left" },
		},
	},
	-- Copilot
	{
		"zbirenbaum/copilot.lua",
		cmd = "Copilot",
		event = "InsertEnter",
		opts = {
			suggestion = {
				enabled = true,
				auto_trigger = true,
				keymap = {
					accept = "<C-l>",
				},
			},
			panel = { enabled = false },
		},
	},

	--- Golang
	{
		"ray-x/go.nvim",
		dependencies = {
			"ray-x/guihua.lua",
			"neovim/nvim-lspconfig",
			"nvim-treesitter/nvim-treesitter",
		},
		config = function()
			require("go").setup()
		end,
		event = { "CmdlineEnter" },
		ft = { "go", "gomod" },
		build = ':lua require("go.install").update_all_sync()',
	},

	--- Blink CMP
	{
		"saghen/blink.cmp",
		version = "*",
		dependencies = {
			"saghen/blink.lib",
		},
		opts = {
			sources = {
				default = { "lsp", "path", "snippets", "buffer" },
			},
		},
	},

	--- Code Action Ligh Bulb
	{ "kosayoda/nvim-lightbulb", event = "LspAttach", priority = 1000, opts = { autocmd = { enabled = true } } },

	{ import = "nvchad.blink.lazyspec" },
	-- Auto Give Commit Messages
	{
		"ajatdarojat45/commitmate.nvim",
		event = "VeryLazy",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"CopilotC-Nvim/CopilotChat.nvim",
		},
		config = function()
			require("commitmate").setup({
				open_lazygit = true,
				ping_message = "CommitMate.nvim is ready",
			})
		end,
	},

	-- Typer
	{
		"nvzone/typr",
		dependencies = "nvzone/volt",
		opts = {},
		cmd = { "Typr", "TyprStats" },
	},

	--- Project for Rooter
	{
		"ahmedkhalf/project.nvim",
		event = "VeryLazy",
		config = function()
			require("project_nvim").setup({
				detection_methods = { "lsp", "pattern" },
				patterns = { ".git", "package.json", "pubspec.yaml", "build.gradle.kts", "module.yaml" },
			})
			local ok, telescope = pcall(require, "telescope")
			if ok then
				pcall(telescope.load_extension, "projects")
			else
				vim.api.nvim_create_autocmd("User", {
					group = vim.api.nvim_create_augroup("ProjectTelescopeLazy", { clear = true }),
					pattern = "LazyLoad",
					callback = function(event)
						if event.data == "telescope.nvim" then
							pcall(require("telescope").load_extension, "projects")
						end
					end,
				})
			end
		end,
	},

	--- Error Diagnostics
	{
		"folke/trouble.nvim",
		cmd = "Trouble",
		opts = {
			auto_refresh = true,
			auto_close = true,
			auto_jump = false,
			focus = false,
			follow = true,
			modes = {
				diagnostics = {
					filter = {
						["not"] = { severity = vim.diagnostic.severity.HINT },
					},
				},
			},
		},
		-- keys = {
		-- 	{
		-- 		"<leader>xx",
		-- 		"<cmd>Trouble diagnostics toggle<cr>",
		-- 		desc = "Project Diagnostics (Trouble)",
		-- 	},
		-- 	{
		-- 		"<leader>xb",
		-- 		"<cmd>Trouble diagnostics toggle filter.buf=0<cr>",
		-- 		desc = "Buffer Diagnostics (Trouble)",
		-- 	},
		-- 	{
		-- 		"<leader>cs",
		-- 		"<cmd>Trouble symbols toggle focus=false<cr>",
		-- 		desc = "Symbols (Trouble)",
		-- 	},
		-- },
	},
	--- Nvim Tree Sitter
	{
		"nvim-treesitter/nvim-treesitter",
		opts = {
			ensure_installed = {
				"vim",
				"lua",
				"vimdoc",
				"html",
				"css",
				-- "kotlin",
				"typescript",
				"java",
				"javascript",
				"dart",
				"go",
				"rust",
				"toml",
				"yaml",
				"tsx",
				"svelte",
				"vue",
			},
		},
	},
	{
		"nvim-telescope/telescope.nvim",
		opts = {
			defaults = {
				file_ignore_patterns = { "node_modules", "%.git/" },
			},
			pickers = {
				find_files = {
					hidden = true,
				},
			},
		},
	},
	{
		"windwp/nvim-ts-autotag",
		event = { "BufReadPre", "BufNewFile" },
		config = function()
			require("nvim-ts-autotag").setup()
		end,
	},
}
