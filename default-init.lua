-- nvim-screen default initialization
-- This file is sourced when starting a new nvim-screen session
--
-- You can customize this by copying it to ~/.config/nvim-screen/init.lua
-- To disable this behavior, create an empty init.lua file

-- Store original quit commands
local original_quit = vim.cmd.quit
local original_qall = vim.cmd.qall

-- Flag to track if we're in a forced quit
local force_quit = false

-- Function to prompt user for detach vs quit
local function quit_with_prompt(bang, args)
    -- If bang (!) is used or force_quit flag is set, quit immediately
    if bang or force_quit then
        force_quit = false
        original_quit({ bang = bang, args = args })
        return
    end

    -- Check if there are unsaved changes
    local modified = vim.bo.modified
    local modified_bufs = 0
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) and vim.api.nvim_buf_get_option(buf, 'modified') then
            modified_bufs = modified_bufs + 1
        end
    end

    -- If there are unsaved changes, warn the user
    if modified or modified_bufs > 0 then
        vim.api.nvim_err_writeln("E37: No write since last change (add ! to override)")
        return
    end

    -- Prompt user
    vim.ui.select(
        {'Detach (keep session running)', 'Quit (close session)'},
        {
            prompt = 'Session is running. What would you like to do?',
            format_item = function(item)
                return item
            end,
        },
        function(choice)
            if choice == 'Detach (keep session running)' then
                -- Detach by closing the channel
                local chan_id = vim.api.nvim_get_chan_info(0).id
                vim.fn.chanclose(chan_id)
            elseif choice == 'Quit (close session)' then
                -- Actually quit
                force_quit = true
                vim.cmd('quit')
            end
            -- If choice is nil (user cancelled), do nothing
        end
    )
end

-- Function to handle qall
local function qall_with_prompt(bang, args)
    -- If bang (!) is used or force_quit flag is set, quit immediately
    if bang or force_quit then
        force_quit = false
        original_qall({ bang = bang, args = args })
        return
    end

    -- Check for unsaved changes in any buffer
    local modified_bufs = 0
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) and vim.api.nvim_buf_get_option(buf, 'modified') then
            modified_bufs = modified_bufs + 1
        end
    end

    if modified_bufs > 0 then
        vim.api.nvim_err_writeln("E37: No write since last change (add ! to override)")
        return
    end

    -- Prompt user
    vim.ui.select(
        {'Detach (keep session running)', 'Quit all (close session)'},
        {
            prompt = 'Session is running. What would you like to do?',
            format_item = function(item)
                return item
            end,
        },
        function(choice)
            if choice == 'Detach (keep session running)' then
                -- Detach by closing the channel
                local chan_id = vim.api.nvim_get_chan_info(0).id
                vim.fn.chanclose(chan_id)
            elseif choice == 'Quit all (close session)' then
                -- Actually quit all
                force_quit = true
                vim.cmd('qall')
            end
        end
    )
end

-- Override quit commands
vim.api.nvim_create_user_command('Q', function(opts)
    quit_with_prompt(opts.bang, opts.args)
end, { bang = true, nargs = '*' })

vim.api.nvim_create_user_command('Quit', function(opts)
    quit_with_prompt(opts.bang, opts.args)
end, { bang = true, nargs = '*' })

vim.api.nvim_create_user_command('Qall', function(opts)
    qall_with_prompt(opts.bang, opts.args)
end, { bang = true, nargs = '*' })

vim.api.nvim_create_user_command('Quitall', function(opts)
    qall_with_prompt(opts.bang, opts.args)
end, { bang = true, nargs = '*' })

vim.api.nvim_create_user_command('Qa', function(opts)
    qall_with_prompt(opts.bang, opts.args)
end, { bang = true, nargs = '*' })

-- Also handle :wq and :x
vim.api.nvim_create_user_command('Wq', function(opts)
    -- Save first
    vim.cmd('write')
    -- Then prompt for quit
    quit_with_prompt(opts.bang, opts.args)
end, { bang = true, nargs = '*' })

vim.api.nvim_create_user_command('X', function(opts)
    -- :x only writes if modified
    if vim.bo.modified then
        vim.cmd('write')
    end
    quit_with_prompt(opts.bang, opts.args)
end, { bang = true, nargs = '*' })

vim.api.nvim_create_user_command('Wqall', function(opts)
    vim.cmd('wall')
    qall_with_prompt(opts.bang, opts.args)
end, { bang = true, nargs = '*' })

vim.api.nvim_create_user_command('Xall', function(opts)
    -- Write all modified buffers
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) and vim.api.nvim_buf_get_option(buf, 'modified') then
            vim.api.nvim_buf_call(buf, function()
                vim.cmd('write')
            end)
        end
    end
    qall_with_prompt(opts.bang, opts.args)
end, { bang = true, nargs = '*' })

-- Add explicit detach and quit commands for clarity
vim.api.nvim_create_user_command('Detach', function()
    local chan_id = vim.api.nvim_get_chan_info(0).id
    vim.fn.chanclose(chan_id)
end, {})

vim.api.nvim_create_user_command('SessionQuit', function(opts)
    force_quit = true
    if opts.bang then
        vim.cmd('qall!')
    else
        vim.cmd('qall')
    end
end, { bang = true })

-- Add a notification that nvim-screen session is active
vim.api.nvim_echo(
    {{
        'nvim-screen session active. Use :Detach to detach, :SessionQuit to quit session, or :q (with prompt)',
        'MoreMsg'
    }},
    false,
    {}
)
