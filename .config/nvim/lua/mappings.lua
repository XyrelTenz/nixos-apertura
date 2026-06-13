require("nvchad.mappings")
local map = vim.keymap.set
map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

-- Code Action map("n", "<leader>ca", function()
--   vim.lsp.buf.code_action()
-- end, { desc = "LSP code action" })

--- Alternative Code Action mapping using Alt key
map("n", "<A-a>", function()
	vim.lsp.buf.code_action()
end, { desc = "LSP Code Action" })

-- Telescope
map("n", "<leader>fr", function()
	require("telescope.builtin").oldfiles()
end, { desc = "Recent Files" })

map("n", "<leader>fp", function()
	require("telescope").extensions.projects.projects({})
end, { desc = "Find Projects" })

map("n", "<leader>fc", function()
	require("telescope.builtin").find_files({ cwd = vim.fn.stdpath("config") })
end, { desc = "Configuration" })

-- Copilot
map("i", "<C-a>", function()
	require("copilot.suggestion").accept()
end, { desc = "Copilot Accept" })

-- Terminal Toggle
map({ "n", "t" }, "<A-i>", function()
	require("nvchad.term").toggle({
		pos = "float",
		id = "floatTerm",
		clear_cmd = true,
		float_opts = {
			row = 0.5,
			col = 0.5,
			width = 0.5,
			height = 0.5,
		},
	})
end, { desc = "terminal toggle floating term" })

-- Transprent Background
map(
	"n",
	"<leader>tt",
	":lua require('base46').toggle_transparency()<CR>",
	{ noremap = true, silent = true, desc = "Toggle Background Transparency" }
)

-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")
-- Flutter
map("n", "<leader>rr", "<cmd>FlutterRun<cr>", { desc = "Flutter Run" })
map("n", "<leader>rd", "<cmd>FlutterDebug<cr>", { desc = "Flutter Debug" })
map("n", "<leader>re", "<cmd>FlutterEmulators<cr>", { desc = "Flutter Emulators" })
map("n", "<leader>rv", "<cmd>FlutterDevices<cr>", { desc = "Flutter Devices" })
map("n", "<leader>rl", "<cmd>FlutterReload<cr>", { desc = "Hot Reload" })
map("n", "<leader>rR", "<cmd>FlutterRestart<cr>", { desc = "Hot Restart" })
map("n", "<leader>rq", "<cmd>FlutterQuit<cr>", { desc = "Quit Flutter" })
map("n", "<leader>ro", "<cmd>FlutterOutlineToggle<cr>", { desc = "Flutter Outline" })
map("n", "<leader>rL", "<cmd>FlutterLogToggle<cr>", { desc = "Flutter Log" })
map("n", "<leader>rc", "<cmd>FlutterLogClear<cr>", { desc = "Clear Flutter Log" })
map("n", "<leader>ra", "<cmd>FlutterAttach<cr>", { desc = "Attach to App" })
map("n", "<leader>rt", "<cmd>FlutterDevTools<cr>", { desc = "Flutter DevTools" })

-- Lazy
map("n", "<leader>l", ":Lazy<cr>", { desc = "Lazy" })

-- Move Lines
map("n", "<A-j>", "<cmd>execute 'move .+' . v:count1<cr>==", { desc = "Move Down" })
map("n", "<A-k>", "<cmd>execute 'move .-' . (v:count1 + 1)<cr>==", { desc = "Move Up" })
map("i", "<A-j>", "<esc><cmd>m .+1<cr>==gi", { desc = "Move Down" })
map("i", "<A-k>", "<esc><cmd>m .-2<cr>==gi", { desc = "Move Up" })
map("v", "<A-j>", ":<C-u>execute \"'<,'>move '>+\" . v:count1<cr>gv=gv", { desc = "Move Down" })
map("v", "<A-k>", ":<C-u>execute \"'<,'>move '<-\" . (v:count1 + 1)<cr>gv=gv", { desc = "Move Up" })

-- Go
map("n", "<leader>gtr", ":GoTest<CR>", { desc = "Run test for current function" })
map("n", "<leader>gtf", ":GoTestFile<CR>", { desc = "Run all tests in file" })
map("n", "<leader>gtp", ":GoTestPkg<CR>", { desc = "Run all tests in package" })
map("n", "<leader>gtc", ":GoCoverage -t<CR>", { desc = "Toggle test coverage signs" })
map("n", "<leader>gr", ":GoRun<CR>", { desc = "Go Run Project" })
map("n", "<leader>gs", ":GoStop<CR>", { desc = "Go Stop Project" })

-- Amper Project Mappings
-- map("n", "<leader>ki", ":!amper init<CR>", { desc = "Amper: Init Project" })
map("n", "<leader>kb", ":!amper build<CR>", { desc = "Amper: Build Project" })
map("n", "<leader>ar", ":!amper run<CR>", { desc = "Amper: Run App" })
map("n", "<leader>at", ":!amper test<CR>", { desc = "Amper: Run Tests" })

-- Introspection & Maintenance
map("n", "<leader>ks", ":!amper show settings<CR>", { desc = "Amper: Show Settings" })
map("n", "<leader>km", ":!amper show modules<CR>", { desc = "Amper: Show Modules" })
map("n", "<leader>kd", ":!amper show dependencies<CR>", { desc = "Amper: Show Deps" })
map("n", "<leader>kc", ":!amper clean<CR>", { desc = "Amper: Clean Build" })

-- Lazygit
map("n", "<leader>gg", function()
	require("snacks").lazygit.open()
end, { desc = "Lazygit" })

-- Gradle
map("n", "<leader>gr", function()
	local current_file = vim.api.nvim_buf_get_name(0)
	local root_file = vim.fs.find({ "gradlew" }, {
		upward = true,
		path = vim.fs.dirname(current_file),
	})[1]

	if root_file then
		local project_root = vim.fs.dirname(root_file)

		local build_gradle = project_root .. "/build.gradle.kts"
		local run_cmd = "./gradlew run"

		local f = io.open(build_gradle, "r")
		if f then
			local content = f:read("*all")
			f:close()
			if content:find("org.springframework.boot") then
				run_cmd = "./gradlew bootRun"
			end
		end

		local command = string.format('clear && cd "%s" && %s', project_root, run_cmd)

		require("nvchad.term").toggle({
			pos = "float",
			id = "floatTerm",
			cmd = command,
		})
	else
		vim.notify("Error: gradlew not found", vim.log.levels.ERROR)
	end
end, { desc = "Run Gradle/SpringBoot Project" })

-- Rust
local map = vim.keymap.set

--- Rust Cargo Commands
map("n", "<leader>cr", function()
	require("nvchad.term").toggle({ pos = "float", id = "floatTerm", cmd = "cargo run" })
end, { desc = "Cargo Run" })

map("n", "<leader>ct", function()
	require("nvchad.term").toggle({ pos = "float", id = "floatTerm", cmd = "cargo test" })
end, { desc = "Cargo Test" })

map("n", "<leader>cc", function()
	require("nvchad.term").toggle({ pos = "float", id = "floatTerm", cmd = "cargo check" })
end, { desc = "Cargo Check" })
