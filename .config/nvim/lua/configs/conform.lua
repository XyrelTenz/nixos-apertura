local options = {
	formatters_by_ft = {
		lua        = { "stylua" },
		css        = { "prettier" },
		html       = { "prettier" },
		kotlin     = { "ktfmt" },
		java       = { "google_java_format" },
		typescript = { "prettier" },
		javascript = { "prettier" },
		vue        = { "prettier" },
		go         = { "goimports", "golines" },
		rust       = { "rustfmt" },
		cpp        = { "clang_format" },
		c          = { "clang_format" },
		nix        = { "alejandra" },
		qml        = { "qmlformat" },
	},

	format_on_save = {
		timeout_ms = 2000,
		lsp_fallback = true,
	},

	formatters = {
		stylua = {
			command = "/run/current-system/sw/bin/stylua",
		},
		prettier = {
			command = "/run/current-system/sw/bin/prettier",
		},
		ktfmt = {
			command = "/run/current-system/sw/bin/ktfmt",
		},
		google_java_format = {
			command = "/run/current-system/sw/bin/google-java-format",
		},
		goimports = {
			command = "/run/current-system/sw/bin/goimports",
		},
		golines = {
			command = "/run/current-system/sw/bin/golines",
		},
		rustfmt = {
			command = "/run/current-system/sw/bin/rustfmt",
		},
		clang_format = {
			command = "/run/current-system/sw/bin/clang-format",
		},
		alejandra = {
			command = "/run/current-system/sw/bin/alejandra",
			args  = { "-" },
			stdin = true,
		},
		-- qmlformat does NOT support stdin — it formats files in-place
		qmlformat = {
			command = "/run/current-system/sw/bin/qmlformat",
			args  = { "--inplace", "$FILENAME" },
			stdin = false,
		},
	},
}

return options
