-- nvim-screen default initialization
-- Sourced by the nvim-screen server when a session starts.
--
-- Makes quit commands screen-like: a quit that would end the session
-- detaches your client instead, keeping the session alive. Quits that
-- only close a window/tab behave as usual.
--
--   :q, :qa, :wq, ZZ, ...   detach when they would end the session
--   :Detach                 detach all clients explicitly
--   :Quit[!]                actually end the session
--   nvim-screen -k <name>   end the session from the shell

local augroup = vim.api.nvim_create_augroup("NvimScreen", { clear = true })

-- Detach every attached UI client; the session keeps running.
local function detach_uis()
	local closed = 0
	for _, ui in ipairs(vim.api.nvim_list_uis()) do
		if ui.chan and ui.chan > 0 then
			pcall(vim.fn.chanclose, ui.chan)
			closed = closed + 1
		end
	end
	return closed
end

-- Count normal (non-floating) windows across all tabpages.
local function normal_window_count()
	local count = 0
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_get_config(win).relative == "" then
			count = count + 1
		end
	end
	return count
end

vim.api.nvim_create_user_command("Detach", function()
	if detach_uis() == 0 then
		vim.notify("nvim-screen: no attached clients", vim.log.levels.WARN)
	end
end, { desc = "nvim-screen: detach all clients, keep session running" })

vim.api.nvim_create_user_command("Quit", function(opts)
	vim.cmd("qall" .. (opts.bang and "!" or ""))
end, { bang = true, desc = "nvim-screen: end the session" })

-- Smart quit, invoked by the abbreviations below with the original command
-- as its argument (e.g. "q", "wq!", "qa"). A quit that only closes a window
-- runs unchanged; a quit that would end the session detaches instead.
vim.api.nvim_create_user_command("NvimScreenQuit", function(opts)
	local arg = opts.args
	local bang = arg:sub(-1) == "!"
	local cmd = bang and arg:sub(1, -2) or arg
	local all = cmd:match("a") ~= nil -- qa, qall, wqa, xall, quitall
	local write = cmd:match("[wx]") ~= nil -- wq, wqa, x, xall

	if not all and normal_window_count() > 1 then
		vim.cmd(arg) -- just closes a window or tab, session unaffected
		return
	end

	-- This quit would end the session: write if asked, then detach.
	if write then
		local ok, err = pcall(vim.cmd, all and "wall" or "update")
		if not ok then
			vim.api.nvim_err_writeln(err)
			return
		end
	end
	detach_uis()
end, { nargs = 1 })

-- Rewrite quit commands on the command line before they run. This is the
-- only reliable interception point: QuitPre/ExitPre autocommands cannot
-- abort an exit, so by the time they fire the session is already dying.
function _G.nvim_screen_expand_quit(lhs)
	if vim.fn.getcmdtype() == ":" and vim.fn.getcmdline() == lhs then
		return "NvimScreenQuit " .. lhs
	end
	return lhs
end

for _, lhs in ipairs({ "q", "quit", "qa", "qall", "quitall", "wq", "wqa", "x", "xall" }) do
	vim.cmd(("cnoreabbrev <expr> %s v:lua.nvim_screen_expand_quit('%s')"):format(lhs, lhs))
end

-- Normal-mode quits.
vim.keymap.set("n", "ZZ", "<Cmd>NvimScreenQuit x<CR>", { desc = "nvim-screen: smart ZZ" })
vim.keymap.set("n", "ZQ", "<Cmd>NvimScreenQuit q!<CR>", { desc = "nvim-screen: smart ZQ" })

-- Greet each client that attaches.
vim.api.nvim_create_autocmd("UIEnter", {
	group = augroup,
	callback = function()
		local name = vim.env.NVIM_SCREEN_SESSION
		vim.defer_fn(function()
			vim.notify(
				("nvim-screen%s: :q detaches, :Quit ends the session"):format(name and (" [" .. name .. "]") or ""),
				vim.log.levels.INFO
			)
		end, 50)
	end,
	desc = "nvim-screen: show session hint on attach",
})
