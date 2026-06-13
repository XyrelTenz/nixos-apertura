require("nvchad.options")
-- vim.g.mapleader = " "
-- vim.g.maplocalleader = " "
vim.g.user = os.getenv("USERNAME") or os.getenv("USER")

local opt = vim.opt

-- Set shell to PowerShell 7 if on Win32 or Win64
local function set_system_shell()
	if vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1 then
		opt.shell = "powershell -NoLogo"
		opt.shellcmdflag =
			"-NoLogo -NoProfile -ExecutionPolicy RemoteSigned -Command [Console]::InputEncoding=[Console]::OutputEncoding=[System.Text.Encoding]::UTF8;"
		opt.shellredir = "-RedirectStandardOutput %s -NoNewWindow -Wait"
		opt.shellpipe = "2>&1 | Out-File -Encoding UTF8 %s; exit $LastExitCode"
		opt.shellquote = ""
		opt.shellxquote = ""
		return
	end

	local shells_to_try = { "zsh", "fish", "bash" }
	for _, shell in ipairs(shells_to_try) do
		if vim.fn.executable(shell) == 1 then
			opt.shell = shell
			return
		end
	end

	opt.shell = "sh"
end

set_system_shell()

-- UI/General
opt.number = true
opt.relativenumber = false
opt.ignorecase = true
opt.cursorline = true
opt.clipboard = "unnamedplus"
opt.termguicolors = true
opt.confirm = true
opt.mouse = "a"
opt.undofile = true
opt.swapfile = false
opt.conceallevel = 1
opt.scrolloff = 12
opt.wrap = true
opt.linebreak = true
opt.spelllang = "en_nz"
opt.showtabline = 0
opt.cmdheight = 0
opt.fillchars:append({ vert = " " })

-- Copilot
vim.g.copilot_no_tab_map = true

-- -- Set statusline
-- opt.laststatus = 0
-- -- opt.statusline = require("core.statusline").statusline
-- -- opt.tabline = require("core.statusline").statusline
--
-- -- Set tab width
-- opt.tabstop = 4
-- opt.shiftwidth = 4
-- opt.expandtab = true
-- opt.autoindent = true
-- opt.breakindent = true
-- opt.breakindentopt = "shift:2"
-- opt.showbreak = "↳"
--
-- Make cursor blink
opt.guicursor = {
	"n-v-c:block,i-ci-ve:ver25,r-cr:hor20,o:hor50",
	"a:blinkwait700-blinkoff400-blinkon250-Cursor/lCursor",
	"sm:block-blinkwait175-blinkoff150-blinkon175",
}
local o = vim.o
o.cursorlineopt = "both"
