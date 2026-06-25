return {
    "nvim-flutter/flutter-tools.nvim",
    lazy = false,
    dependencies = {
        "nvim-lua/plenary.nvim",
        "stevearc/dressing.nvim",
    },
    config = function()
        local nvlsp = require("nvchad.configs.lspconfig")

        local flutter_bin = vim.fn.executable("flutter") == 1 and vim.fn.exepath("flutter") or nil

        require("flutter-tools").setup({
            flutter_path = flutter_bin,
            
            fvm = false, 

            emulator_args = {
                "--enable-gpu-libvulkan",
                "--gpu",
                "host",
            },
            executable = {
                env = {
                    QT_QPA_PLATFORM = "xcb",
                },
            },
            ui = {
                border = "rounded",
            },
            decorations = {
                statusline = {
                    app_version = true,
                    device = true,
                },
            },
            debugger = {
                enabled = false,
                run_via_dap = false,
            },
            widget_guides = {
                enabled = true,
            },
            closing_tags = {
                highlight = "Comment",
                prefix = "//",
                enabled = true,
            },
            dev_log = {
                filter = nil,
                enabled = true,
                open_cmd = "15split",
            },
            outline = {
                auto_open = false,
                width = 100,
            },
            dev_tools = {
                autostart = false,
                auto_open_browser = false,
            },
            lsp = {
                capabilities = nvlsp.capabilities,
                on_attach = nvlsp.on_attach,
                settings = {
                    showTodos = true,
                    completeFunctionCalls = true,
                    renameFilesWithClasses = "prompt",
                    updateImportsOnRename = true,
                    dart_code_metrics = true,
                },
            },
        })

        vim.api.nvim_create_autocmd("BufWritePre", {
            pattern = "*.dart",
            callback = function()
                vim.lsp.buf.format({ async = false })
            end,
        })
    end,
}