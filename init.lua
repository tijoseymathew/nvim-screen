-- nvim-screen default initialization
-- Sourced by the nvim-screen server when a session starts.
--
-- Detaching follows GNU screen's convention: a prefix key, then a command.
-- Quit commands are left alone and mean what they have always meant.
--
--   <prefix> d              detach; the session keeps running
--   <prefix> a              send the prefix key itself (screen's convention)
--   :detach                 same as <prefix> d, from the command line (built into Neovim)
--   :q, :qa, :wq, ZZ, ...   ordinary Neovim quits - the last one ends the session
--   nvim-screen -k <name>   end the session from the shell
--
-- Change this to customize the prefix (Neovim key notation). Bare <prefix> is
-- deliberately left unmapped: after 'timeoutlen' it falls through to
-- whatever it normally does (Ctrl+a increments the number under the
-- cursor), and <prefix> a does the same thing without the wait.
local prefix = "<C-a>"

local augroup = vim.api.nvim_create_augroup("NvimScreen", { clear = true })

vim.keymap.set("n", prefix .. "d", "<Cmd>detach<CR>", {
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
				("nvim-screen%s: %s d (or :detach) detaches, :qa ends the session"):format(
					name and (" [" .. name .. "]") or "",
					prefix_label
				),
				vim.log.levels.INFO
			)
		end, 50)
	end,
	desc = "nvim-screen: show session hint on attach",
})
