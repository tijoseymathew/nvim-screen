-- nvim-screen default initialization
-- This file is sourced when starting a new nvim-screen session.
-- It uses the QuitPre autocommand to intercept exit attempts.

-- This function is called just before Neovim tries to quit.
local function on_quit_pre()
	-- Don't show the prompt if there are unsaved changes.
	-- Neovim will handle that with its default "E37" error.
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(buf) and vim.api.nvim_get_option_value("modified", { buf = buf }) then
			return
		end
	end

	-- Prompt the user for what to do next.
	vim.ui.select({ "Detach", "Quit all" }, { prompt = "Close session or detach?" }, function(choice)
		if choice == "Detach" then
			-- The 'detach' command will stop the quit process and detach.
			vim.cmd("detach")
		elseif choice == "Quit all" then
			-- If the user confirms, we quit forcefully.
			-- We use 'qall!' to bypass any further checks.
			vim.cmd("qall!")
		end
		-- If the user closes the prompt without a choice, the quit is aborted.
	end)

	-- By creating a UI select prompt, we effectively "block" the execution
	-- and prevent Neovim from quitting immediately. The quit process will
	-- only continue if we explicitly call a quit command (like 'qall!') inside
	-- the callback.
	vim.cmd("stopinsert") -- a trick to ensure the UI prompt shows correctly.
end

-- Create an autocommand group to ensure our command doesn't get duplicated.
local nvim_screen_augroup = vim.api.nvim_create_augroup("NvimScreen", { clear = true })

-- Attach our function to the QuitPre event.
vim.api.nvim_create_autocmd("QuitPre", {
	group = nvim_screen_augroup,
	pattern = "*",
	callback = on_quit_pre,
	desc = "Prompt to detach or quit before closing nvim.",
})

-- Show a subtle message that the session is active.
vim.notify("nvim-screen session active (use :detach to detach)", vim.log.levels.INFO)
