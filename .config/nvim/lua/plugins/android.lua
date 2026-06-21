return {
	"iamironz/android-nvim-plugin",
	event = "VeryLazy",
	config = function()
		require("android").setup()
	end,
}
