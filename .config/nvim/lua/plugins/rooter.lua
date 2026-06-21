return {
	"notjedi/nvim-rooter.lua",
	event = { "BufReadPre", "BufNewFile" },
	config = function()
		require("nvim-rooter").setup({
			update_cwd = true,
			trigger_patterns = { "*" },
			rooter_patterns = {
				".git",
				".hg",
				".svn",
				"build.gradle.kts",
				"settings.gradle.kts",
				"pubspec.yaml",
				"module.yaml",
				"amper.bat",
				"amper.sh",
				".agent",
				"flutter_yaml_bridge.yaml",
				"rust-project.json",
			},
		})
	end,
}
