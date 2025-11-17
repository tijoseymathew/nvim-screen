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

        -- Check for unsaved changes - Neovim will handle this, but we want consistent UX
        local modified = vim.bo.modified
        if modified then
            vim.api.nvim_echo({{"E37: No write since last change (add ! to override)", "ErrorMsg"}}, false, {})
            error("")  -- Abort the quit
        end

        -- Schedule the prompt to avoid blocking the quit event
        vim.schedule(function()
            vim.ui.select(
                {'Detach', 'Quit'},
                { prompt = 'Close session or detach?' },
                function(choice)
                    if choice == 'Detach' then
                        vim.cmd('detach')
                    elseif choice == 'Quit' then
                        -- Use force quit to bypass this autocmd
                        vim.cmd('quit!')
                    end
                    -- If choice is nil (cancelled), do nothing
                end
            )
        end)

        -- Abort the current quit attempt
        error("")  -- Empty error to minimize output
    end
})

-- Show a subtle message that session is active
vim.notify("nvim-screen session active (use :detach to detach)", vim.log.levels.INFO)
