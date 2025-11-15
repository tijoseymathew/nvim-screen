-- nvim-screen default initialization
-- This file is sourced when starting a new nvim-screen session
--
-- You can customize this by copying it to ~/.config/nvim-screen/init.lua
-- To disable this behavior, create an empty init.lua file

-- Prompt user for detach vs quit
_G.nvim_screen_quit_prompt = function(write_cmd, force)
    -- If force quit (!) is used, just quit
    if force then
        if write_cmd then
            vim.cmd(write_cmd)
        end
        vim.cmd('quit!')
        return
    end

    -- Check for unsaved changes
    local modified = vim.bo.modified
    if modified then
        vim.api.nvim_err_writeln("E37: No write since last change (add ! to override)")
        return
    end

    -- Write if requested
    if write_cmd then
        vim.cmd(write_cmd)
    end

    -- Prompt user
    vim.ui.select(
        {'Detach', 'Quit'},
        { prompt = 'Close session or detach?' },
        function(choice)
            if choice == 'Detach' then
                vim.fn.chanclose(vim.api.nvim_get_chan_info(0).id)
            elseif choice == 'Quit' then
                vim.cmd('quit!')
            end
        end
    )
end

-- Similar for qall
_G.nvim_screen_quitall_prompt = function(write_cmd, force)
    if force then
        if write_cmd then
            vim.cmd(write_cmd)
        end
        vim.cmd('qall!')
        return
    end

    -- Check for unsaved changes in any buffer
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) and vim.api.nvim_buf_get_option(buf, 'modified') then
            vim.api.nvim_err_writeln("E37: No write since last change (add ! to override)")
            return
        end
    end

    if write_cmd then
        vim.cmd(write_cmd)
    end

    vim.ui.select(
        {'Detach', 'Quit all'},
        { prompt = 'Close session or detach?' },
        function(choice)
            if choice == 'Detach' then
                vim.fn.chanclose(vim.api.nvim_get_chan_info(0).id)
            elseif choice == 'Quit all' then
                vim.cmd('qall!')
            end
        end
    )
end

-- Command abbreviations to intercept quit commands
vim.cmd([[
    cnoreabbrev <expr> q getcmdtype() == ':' && getcmdline() == 'q' ? 'lua nvim_screen_quit_prompt(nil, false)' : 'q'
    cnoreabbrev <expr> q! getcmdtype() == ':' && getcmdline() == 'q!' ? 'lua nvim_screen_quit_prompt(nil, true)' : 'q!'
    cnoreabbrev <expr> quit getcmdtype() == ':' && getcmdline() == 'quit' ? 'lua nvim_screen_quit_prompt(nil, false)' : 'quit'
    cnoreabbrev <expr> quit! getcmdtype() == ':' && getcmdline() == 'quit!' ? 'lua nvim_screen_quit_prompt(nil, true)' : 'quit!'

    cnoreabbrev <expr> qa getcmdtype() == ':' && getcmdline() == 'qa' ? 'lua nvim_screen_quitall_prompt(nil, false)' : 'qa'
    cnoreabbrev <expr> qa! getcmdtype() == ':' && getcmdline() == 'qa!' ? 'lua nvim_screen_quitall_prompt(nil, true)' : 'qa!'
    cnoreabbrev <expr> qall getcmdtype() == ':' && getcmdline() == 'qall' ? 'lua nvim_screen_quitall_prompt(nil, false)' : 'qall'
    cnoreabbrev <expr> qall! getcmdtype() == ':' && getcmdline() == 'qall!' ? 'lua nvim_screen_quitall_prompt(nil, true)' : 'qall!'

    cnoreabbrev <expr> wq getcmdtype() == ':' && getcmdline() == 'wq' ? 'lua nvim_screen_quit_prompt("write", false)' : 'wq'
    cnoreabbrev <expr> wq! getcmdtype() == ':' && getcmdline() == 'wq!' ? 'lua nvim_screen_quit_prompt("write", true)' : 'wq!'
    cnoreabbrev <expr> x getcmdtype() == ':' && getcmdline() == 'x' ? 'lua nvim_screen_quit_prompt(vim.bo.modified and "write" or nil, false)' : 'x'
    cnoreabbrev <expr> x! getcmdtype() == ':' && getcmdline() == 'x!' ? 'lua nvim_screen_quit_prompt(vim.bo.modified and "write" or nil, true)' : 'x!'

    cnoreabbrev <expr> wqa getcmdtype() == ':' && getcmdline() == 'wqa' ? 'lua nvim_screen_quitall_prompt("wall", false)' : 'wqa'
    cnoreabbrev <expr> wqa! getcmdtype() == ':' && getcmdline() == 'wqa!' ? 'lua nvim_screen_quitall_prompt("wall", true)' : 'wqa!'
    cnoreabbrev <expr> xall getcmdtype() == ':' && getcmdline() == 'xall' ? 'lua nvim_screen_quitall_prompt("wall", false)' : 'xall'
    cnoreabbrev <expr> xall! getcmdtype() == ':' && getcmdline() == 'xall!' ? 'lua nvim_screen_quitall_prompt("wall", true)' : 'xall!'
]])

-- Explicit detach command for convenience
vim.api.nvim_create_user_command('Detach', function()
    vim.fn.chanclose(vim.api.nvim_get_chan_info(0).id)
end, {})

-- Show a subtle message that session is active
vim.notify("nvim-screen session active (use :Detach to detach)", vim.log.levels.INFO)
