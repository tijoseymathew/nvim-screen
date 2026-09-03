-- nvim-screen default initialization
-- Sourced by the nvim-screen server when a session starts.
--
-- Detaching follows GNU screen's convention: a prefix key, then a command.
-- Quit commands are left alone and mean what they have always meant.
--
--   <prefix> d              detach; the session keeps running
--   <prefix> a              send the prefix key itself (screen's convention)
--   :Detach                 same as <prefix> d, from the command line
--   :q, :qa, :wq, ZZ, ...   ordinary Neovim quits - the last one ends the session
--   nvim-screen -k <name>   end the session from the shell
--
-- The prefix defaults to Ctrl+a and is set by the nvim-screen script through
-- $NVIM_SCREEN_PREFIX, so it is configured in one place for both. Bare
-- <prefix> is deliberately left unmapped: after 'timeoutlen' it falls through
-- to whatever it normally does (Ctrl+a increments the number under the
-- cursor), and <prefix> a does the same thing without the wait.

local augroup = vim.api.nvim_create_augroup("NvimScreen", { clear = true })

local prefix = vim.env.NVIM_SCREEN_PREFIX
if prefix == nil or prefix == "" then
	prefix = "<C-a>"
end

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

local function detach()
	if detach_uis() == 0 then
		vim.notify("nvim-screen: no attached clients", vim.log.levels.WARN)
	end
end

vim.api.nvim_create_user_command("Detach", detach, {
	desc = "nvim-screen: detach all clients, keep session running",
})

vim.keymap.set("n", prefix .. "d", detach, {
	desc = "nvim-screen: detach (session keeps running)",
})

-- Screen's escape convention: the prefix twice-over sends the key itself.
vim.keymap.set("n", prefix .. "a", prefix, {
	desc = "nvim-screen: send " .. prefix,
})

-- "<C-a>" reads as "Ctrl+a" in the hint below.
local prefix_label = prefix:gsub("^<[Cc]%-(.)>$", "Ctrl+%1")

-- Greet each client that attaches.
vim.api.nvim_create_autocmd("UIEnter", {
	group = augroup,
	callback = function()
		local name = vim.env.NVIM_SCREEN_SESSION
		vim.defer_fn(function()
			vim.notify(
				("nvim-screen%s: %s d (or :Detach) detaches, :qa ends the session"):format(
					name and (" [" .. name .. "]") or "",
					prefix_label
				),
				vim.log.levels.INFO
			)
		end, 50)
	end,
	desc = "nvim-screen: show session hint on attach",
})
