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

-- Session switching --------------------------------------------------------
-- nvim-screen exports NVIM_SCREEN_SESSION and NVIM_SCREEN_DIR when it starts
-- the server. :SwitchSession writes the target session name to a switch file
-- and detaches the invoking UI; the nvim-screen wrapper that owns that UI
-- picks up the file and re-attaches to the requested session.

local uv = vim.uv or vim.loop
local session_name = vim.env.NVIM_SCREEN_SESSION
local session_dir = vim.env.NVIM_SCREEN_DIR

-- List other sessions by scanning the session directory for sockets.
local function list_other_sessions()
	local sessions = {}
	if not session_dir then
		return sessions
	end
	for name in vim.fs.dir(session_dir) do
		local other = name:match("^nvim%-session%-(.+)%.sock$")
		if other and other ~= session_name then
			table.insert(sessions, other)
		end
	end
	table.sort(sessions)
	return sessions
end

-- List host:-prefixes for hosts with an SSH control socket, so remote
-- targets like host:session can be tab-completed up to the colon.
local function list_ssh_host_prefixes()
	local hosts = {}
	if not session_dir then
		return hosts
	end
	for name in vim.fs.dir(session_dir) do
		local host = name:match("^ssh%-control%-(.+)%.sock$")
		if host then
			table.insert(hosts, host .. ":")
		end
	end
	table.sort(hosts)
	return hosts
end

local function switch_to(target)
	if not (session_dir and session_name) then
		vim.notify(
			"nvim-screen: session environment not set; start this session with nvim-screen to enable switching",
			vim.log.levels.ERROR
		)
		return
	end
	if target == session_name then
		vim.notify("Already in session '" .. target .. "'", vim.log.levels.INFO)
		return
	end
	-- host:session targets are handled by the wrapper, which hops over SSH.
	-- Existence can only be verified there; on failure the wrapper falls
	-- back to re-attaching to this session.
	local is_remote = target:match("^[^:]+:.+$") ~= nil
	if not is_remote and not uv.fs_stat(session_dir .. "/nvim-session-" .. target .. ".sock") then
		vim.notify("nvim-screen: no session named '" .. target .. "'", vim.log.levels.ERROR)
		return
	end

	local switch_file = session_dir .. "/switch-" .. session_name
	local f, err = io.open(switch_file, "w")
	if not f then
		vim.notify("nvim-screen: cannot write switch file: " .. tostring(err), vim.log.levels.ERROR)
		return
	end
	f:write(target .. "\n")
	f:close()

	-- Detach the UI that invoked the command; its nvim-screen wrapper reads
	-- the switch file and attaches to the target session. If the detach
	-- fails (e.g. no UI on this channel), remove the switch file so a later
	-- detach doesn't trigger a surprise switch.
	local ok, detach_err = pcall(vim.cmd, "detach")
	if not ok then
		os.remove(switch_file)
		vim.notify("nvim-screen: switch aborted, could not detach: " .. tostring(detach_err), vim.log.levels.ERROR)
	end
end

vim.api.nvim_create_user_command("SwitchSession", function(opts)
	if opts.args ~= "" then
		switch_to(opts.args)
		return
	end
	local sessions = list_other_sessions()
	if #sessions == 0 then
		vim.notify("nvim-screen: no other sessions to switch to", vim.log.levels.INFO)
		return
	end
	vim.ui.select(sessions, { prompt = "Switch to session:" }, function(choice)
		if choice then
			switch_to(choice)
		end
	end)
end, {
	nargs = "?",
	complete = function(arg_lead)
		local candidates = list_other_sessions()
		vim.list_extend(candidates, list_ssh_host_prefixes())
		return vim.tbl_filter(function(s)
			return vim.startswith(s, arg_lead)
		end, candidates)
	end,
	desc = "Detach this client and attach it to another nvim-screen session (name or host:name).",
})

-- Show a subtle message that the session is active.
vim.notify("nvim-screen session active (:detach to detach, :SwitchSession to switch)", vim.log.levels.INFO)
