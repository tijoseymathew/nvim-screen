-- nvim-screen default initialization
-- Sourced by the nvim-screen server when a session starts.
--
-- Detaching follows GNU screen's convention: a prefix key, then a command.
-- Quit commands are left alone and mean what they have always meant.
--
--   <prefix> d              detach; the session keeps running
--   <prefix> a              send the prefix key itself (screen's convention)
--   :Detach                 same as <prefix> d, from the command line
--   <leader>s / :Sessions   pick another session and switch to it
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

-- ---------------------------------------------------------------------------
-- Switching sessions
--
-- The picker offers the same list `nvim-screen -ls` prints - every session on
-- this machine plus every session on every host the originating machine has
-- talked to - and any of them is one keystroke away, whether you are local or
-- three hops out.
--
-- Which sessions are knowable from here depends on where "here" is. Sessions
-- on this machine are enumerated directly: instant and always current. The
-- rest can only be swept by the machine that owns the ssh config, so it hands
-- them over as a snapshot; when this session is on the far side of an SSH hop
-- that snapshot is frozen as of when the hop started.
--
-- Moving is two different things depending on the target:
--
--   same machine   Neovim's `:connect` walks the UI over to the other server.
--                  Nothing is torn down and nothing flickers. The hop context
--                  below is copied to the target first, so the session you
--                  land on can switch onwards exactly like this one.
--   anywhere else  `:connect` does no tunneling, so the target is written
--                  where the nvim-screen wrapper will find it and every client
--                  is dropped. The wrapper on the user's own machine - the
--                  only one with their ssh config - reattaches from there.
-- ---------------------------------------------------------------------------

local function session_dir()
	local dir = vim.env.NVIM_SCREEN_SESSION_DIR
	if dir and dir ~= "" then
		return dir
	end
	-- Sessions started by an older nvim-screen were not told; the script
	-- builds the path this way, so build the same one.
	local user = vim.env.USER or vim.env.LOGNAME or ""
	return (vim.env.XDG_RUNTIME_DIR or "/tmp") .. "/nvim-sessions-" .. user
end

local function socket_path(dir, name)
	return dir .. "/nvim-session-" .. name .. ".sock"
end

-- What nvim-screen left for us about the hop this session is being used
-- through: which host we are on as the originating machine addresses it,
-- where the session snapshot is, and where to leave a switch request.
local function hop_context()
	local dir = session_dir()
	local ctx = {
		host = vim.env.NVIM_SCREEN_HOST or "",
		snapshot = "",
		switch = "",
		attached = "",
		dir = dir,
	}

	local file = io.open(dir .. "/.ctx-" .. (vim.env.NVIM_SCREEN_SESSION or ""), "r")
	if not file then
		return ctx
	end
	for line in file:lines() do
		local key, value = line:match("^([^\t]+)\t(.*)$")
		if key == "socketdir" then
			ctx.dir = value ~= "" and value or ctx.dir
		elseif key and ctx[key] ~= nil then
			ctx[key] = value
		end
	end
	file:close()
	return ctx
end

local function write_hop_context(ctx, name)
	local file = io.open(ctx.dir .. "/.ctx-" .. name, "w")
	if not file then
		return
	end
	file:write(("host\t%s\n"):format(ctx.host))
	file:write(("snapshot\t%s\n"):format(ctx.snapshot))
	file:write(("switch\t%s\n"):format(ctx.switch))
	file:write(("attached\t%s\n"):format(ctx.attached))
	file:write(("socketdir\t%s\n"):format(ctx.dir))
	file:close()
end

-- Tell the wrapper which session its client ended up on, so that after a
-- chain of `:connect` hops it still reports the right name.
local function note_attached(ctx, name)
	if ctx.attached == "" then
		return
	end
	local file = io.open(ctx.attached, "w")
	if file then
		file:write(name .. "\n")
		file:close()
	end
end

-- Cheapest possible liveness check: open an RPC channel to the socket and
-- close it again. No subprocess, unlike the script's equivalent.
local function responsive(path)
	if path == vim.v.servername then
		return true
	end
	local ok, chan = pcall(vim.fn.sockconnect, "pipe", path, { rpc = true })
	if ok and type(chan) == "number" and chan > 0 then
		pcall(vim.fn.chanclose, chan)
		return true
	end
	return false
end

-- Drop whatever is still attached to the session we are about to walk into.
-- Neovim sizes the screen to the smallest attached UI, so a leftover client
-- from a dropped connection is exactly what makes a session look mangled.
local function evict_uis(path)
	if vim.env.NVIM_SCREEN_SHARE == "1" then
		return
	end
	local ok, chan = pcall(vim.fn.sockconnect, "pipe", path, { rpc = true })
	if not (ok and type(chan) == "number" and chan > 0) then
		return
	end
	pcall(
		vim.rpcrequest,
		chan,
		"nvim_exec_lua",
		"for _, ui in ipairs(vim.api.nvim_list_uis()) do"
			.. " if ui.chan and ui.chan > 0 then pcall(vim.fn.chanclose, ui.chan) end"
			.. " end",
		{}
	)
	pcall(vim.fn.chanclose, chan)
end

-- Sessions on this machine, enumerated where they actually are.
local function sessions_here(ctx)
	local found = {}
	for _, path in ipairs(vim.fn.glob(ctx.dir .. "/nvim-session-*.sock", true, true)) do
		local name = path:match("/nvim%-session%-(.+)%.sock$")
		if name then
			found[#found + 1] = {
				host = ctx.host,
				name = name,
				path = path,
				alive = responsive(path),
				here = true,
			}
		end
	end
	table.sort(found, function(a, b)
		return a.name < b.name
	end)
	return found
end

-- Everywhere else, from the snapshot. Entries for the host we are on are
-- dropped: we just enumerated those for real.
local function sessions_elsewhere(ctx)
	local found = {}
	if ctx.snapshot == "" then
		return found
	end
	local file = io.open(ctx.snapshot, "r")
	if not file then
		return found
	end
	for line in file:lines() do
		local host, name, state = line:match("^([^\t]*)\t([^\t]*)\t([^\t]*)$")
		if name and name ~= "" and host ~= ctx.host then
			found[#found + 1] = {
				host = host,
				name = name,
				alive = state ~= "down",
				here = false,
			}
		end
	end
	file:close()
	return found
end

-- How the nvim-screen wrapper on the user's own machine addresses an entry.
local function target_of(entry)
	if entry.host == "" then
		return entry.name
	end
	return entry.host .. ":" .. entry.name
end

local function format_entry(entry)
	local current = entry.here and entry.name == vim.env.NVIM_SCREEN_SESSION
	local note = ""
	if current then
		note = "  (this session)"
	elseif not entry.alive then
		note = "  (unresponsive)"
	end
	return ("%s %-16s %s%s"):format(
		entry.alive and "●" or "○",
		entry.host == "" and "[local]" or ("[" .. entry.host .. "]"),
		entry.name,
		note
	)
end

-- Ask nvim-screen to re-sweep, so the next time the picker opens its view of
-- the other hosts is current. Only meaningful on the originating machine: a
-- session out on a remote host has no ssh config to sweep with, which is why
-- it was handed a snapshot in the first place.
local function refresh_snapshot(ctx)
	if ctx.host ~= "" or not vim.system then
		return
	end
	local exe = vim.fn.exepath("nvim-screen")
	if exe == "" then
		return
	end
	pcall(vim.system, { exe, "-snapshot" }, { detach = true })
end

local function switch_to(ctx, entry)
	if entry.here and entry.name == vim.env.NVIM_SCREEN_SESSION then
		return
	end

	-- Same address space: hand the UI straight over, no teardown.
	if entry.here and vim.fn.exists(":connect") == 2 and #vim.api.nvim_list_uis() > 0 then
		local path = entry.path or socket_path(ctx.dir, entry.name)
		evict_uis(path)
		write_hop_context(ctx, entry.name)
		note_attached(ctx, entry.name)
		local ok = pcall(vim.cmd, "connect " .. vim.fn.fnameescape(path))
		-- `:connect` works out which UI to move from where the input came
		-- from, so it can move it and still report an error - and, either
		-- way, it detaches. If our clients have gone the hop happened; only
		-- fall through to the wrapper when nothing moved at all.
		if ok or #vim.api.nvim_list_uis() == 0 then
			-- Nothing is attached here any more, so this session's context
			-- is spent; it now belongs to the one we handed the UI to.
			os.remove(ctx.dir .. "/.ctx-" .. (vim.env.NVIM_SCREEN_SESSION or ""))
			return
		end
	end

	-- Anywhere else - and the fallback when this Neovim has no `:connect`.
	if ctx.switch == "" then
		vim.notify(
			"nvim-screen: this session is not attached through nvim-screen, so there is "
				.. "nothing to hand the switch to",
			vim.log.levels.ERROR
		)
		return
	end

	local file = io.open(ctx.switch, "w")
	if not file then
		vim.notify("nvim-screen: cannot write " .. ctx.switch, vim.log.levels.ERROR)
		return
	end
	file:write(target_of(entry) .. "\n")
	file:close()

	if detach_uis() == 0 then
		os.remove(ctx.switch)
		vim.notify("nvim-screen: no attached clients", vim.log.levels.WARN)
	end
end

local function pick_session()
	local ctx = hop_context()
	refresh_snapshot(ctx)

	local entries = sessions_here(ctx)
	for _, entry in ipairs(sessions_elsewhere(ctx)) do
		entries[#entries + 1] = entry
	end

	local elsewhere = 0
	for _, entry in ipairs(entries) do
		if not (entry.here and entry.name == vim.env.NVIM_SCREEN_SESSION) then
			elsewhere = elsewhere + 1
		end
	end
	if elsewhere == 0 then
		vim.notify("nvim-screen: no other sessions to switch to", vim.log.levels.WARN)
		return
	end

	vim.ui.select(entries, {
		prompt = "nvim-screen: switch to session",
		format_item = format_entry,
	}, function(entry)
		if entry then
			switch_to(ctx, entry)
		end
	end)
end

vim.api.nvim_create_user_command("Sessions", pick_session, {
	desc = "nvim-screen: pick another session and switch to it",
})

-- Unlike the detach binding this one is not a screen convention, so it is
-- easy to want somewhere else - or nowhere, if it collides with your own
-- mapping. An empty NVIM_SCREEN_SWITCH_KEY leaves the key alone.
local switch_key = vim.env.NVIM_SCREEN_SWITCH_KEY
if switch_key == nil then
	switch_key = "<leader>s"
end
if switch_key ~= "" then
	vim.keymap.set("n", switch_key, pick_session, {
		desc = "nvim-screen: switch session",
	})
end

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
