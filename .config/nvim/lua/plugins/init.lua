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
		config = function()
			require("configs.lspconfig")
		end,
	},
	{
		"nvim-tree/nvim-tree.lua",
		opts = {
			sync_root_with_cwd = true,
			respect_buf_cwd = false,
			update_focused_file = {
				enable = true,
				update_root = false,
			},
			prefer_startup_root = true,
			filters = {
				custom = { "node_modules", "target", "build", "dist", "out" },
				dotfiles = false,
			},
			git = {
				ignore = false,
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
	{ import = "nvchad.blink.lazyspec" },
	{
		"ajatdarojat45/commitmate.nvim",
		lazy = false,
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
	{
		"ahmedkhalf/project.nvim",
		lazy = false,
		config = function()
			require("project_nvim").setup({
				detection_methods = { "lsp", "pattern" },
				patterns = { ".git", "melos.yaml" },
				ignore_lsp = { "rust_analyzer" },
			})
		end,
	},
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
	},
	{
		"nvim-treesitter/nvim-treesitter",
		opts = {
			ensure_installed = {
				"vim",
				"lua",
				"vimdoc",
				"html",
				"css",
				"typescript",
				"javascript",
				"go",
				"rust",
				"toml",
				"yaml",
				"tsx",
				"svelte",
				"vue",
				"qml",
			},
		},
	},
	{
		"nvim-telescope/telescope.nvim",
		opts = {
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
