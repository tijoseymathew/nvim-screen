-- nvim-screen default initialization
-- This file is sourced when starting a new nvim-screen session
--
-- You can customize this by editing ~/.config/nvim-screen/init.lua
-- To disable this behavior, delete the config file

-- Use QuitPre autocommand to intercept quit attempts
vim.api.nvim_create_autocmd("QuitPre", {
    group = vim.api.nvim_create_augroup("nvim_screen_quit_prompt", { clear = true }),
    callback = function()
        -- Check if it's a force quit by looking at the last command
        local last_cmd = vim.fn.histget('cmd', -1)
        if last_cmd:match('!%s*$') then
            -- Force quit - allow it to proceed
            return
        end

        -- Show synchronous prompt
        local choice = vim.fn.confirm(
            'Close session or detach?',
            '&Detach\n&Quit',
            1  -- Default to Detach
        )

        if choice == 1 then
            -- Detach - close connection but keep server running
            vim.cmd('detach')
            return  -- Don't error - detach will handle closing
        elseif choice == 2 then
            -- Quit - use ! to bypass this autocmd
            vim.cmd('quit!')
            return  -- Don't error - we already quit
        end

        -- If choice == 0 (cancelled with Esc), prevent the quit
        error("")
    end
})

-- Show a subtle message that session is active
vim.notify("nvim-screen session active (use :detach to detach)", vim.log.levels.INFO)
