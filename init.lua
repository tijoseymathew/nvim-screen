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

-- ---------------------------------------------------------------------------
-- Open files from terminals in this session instead of nesting nvim.
--
-- Typing `nvim file` in a :terminal inside the session would normally start a
-- second Neovim inside the terminal. Instead, an `nvim` wrapper is put first
-- on $PATH for everything the session starts. When it runs interactively in
-- one of the session's terminals, it asks this server ($NVIM) to open the
-- files in a new tab and waits until you're done with them, just as a nested
-- nvim would. That way `git commit` and other $EDITOR users work too. `:q` closes
-- the tab and takes you back to the terminal.
--
-- Relative paths are resolved against the terminal's working directory, not
-- the session's, and the new tab gets that directory as its :tcd.
--
-- Anything the wrapper doesn't understand (options like -d, -l, --headless,
-- reading stdin with -) runs the real nvim, unchanged. So does any run without
-- a tty on stdin and stdout (:!, system(), pipes), which also keeps a
-- synchronous :!nvim from waiting on the server it is blocking.
-- NVIM_SCREEN_NESTED=1 forces a real nested nvim.

local edit_requests = {}
local next_edit_id = 0

local function resolve(cwd, path)
	if path:sub(1, 1) ~= "/" then
		path = cwd .. "/" .. path
	end
	return vim.fs.normalize(path)
end

local function edit_done(req)
	for _, buf in ipairs(req.bufs) do
		if vim.api.nvim_buf_is_valid(buf) and #vim.fn.win_findbuf(buf) > 0 then
			return false
		end
	end
	return true
end

local function check_edit_requests()
	for id, req in pairs(edit_requests) do
		if edit_done(req) then
			edit_requests[id] = nil
			-- Back to the terminal the request came from, like leaving a
			-- nested nvim.
			if req.win and vim.api.nvim_win_is_valid(req.win) then
				vim.api.nvim_set_current_win(req.win)
				if vim.bo[vim.api.nvim_win_get_buf(req.win)].buftype == "terminal" then
					vim.cmd("startinsert")
				end
			end
		end
	end
end

-- Called by the wrapper: open `args` (file names and +commands, as given to
-- nvim) relative to `cwd`. Returns a request id to poll with
-- NvimScreenEditPending().
function _G.NvimScreenEdit(cwd, args)
	local files, cmds = {}, {}
	local only_files = false
	for _, arg in ipairs(args) do
		if not only_files and arg == "--" then
			only_files = true
		elseif not only_files and arg:sub(1, 1) == "+" then
			table.insert(cmds, arg == "+" and "$" or arg:sub(2))
		else
			table.insert(files, resolve(cwd, arg))
		end
	end

	local cur = vim.api.nvim_get_current_win()
	local origin = vim.bo[vim.api.nvim_win_get_buf(cur)].buftype == "terminal" and cur or nil

	-- Leave terminal mode first; it would otherwise carry over to the new
	-- tab's window.
	if vim.api.nvim_get_mode().mode == "t" then
		vim.cmd("stopinsert")
	end

	-- Errors are reported here rather than returned: the wrapper would
	-- otherwise fall back to a nested nvim and open the file twice.
	local function try(cmd)
		local ok, err = pcall(vim.cmd, cmd)
		if not ok then
			vim.notify(err, vim.log.levels.ERROR)
		end
	end

	vim.cmd("tabnew")
	try("tcd " .. vim.fn.fnameescape(cwd))
	if #files > 0 then
		try("edit " .. vim.fn.fnameescape(files[1]))
	end

	local bufs = { vim.api.nvim_get_current_buf() }
	for i = 2, #files do
		local buf = vim.fn.bufadd(files[i])
		vim.bo[buf].buflisted = true
		table.insert(bufs, buf)
	end
	for _, c in ipairs(cmds) do
		try(c)
	end

	next_edit_id = next_edit_id + 1
	edit_requests[next_edit_id] = { bufs = bufs, win = origin }
	return next_edit_id
end

function _G.NvimScreenEditPending(id)
	return edit_requests[id] and 1 or 0
end

vim.api.nvim_create_autocmd({ "BufWinLeave", "BufDelete", "WinClosed", "TabClosed" }, {
	group = augroup,
	callback = function()
		if next(edit_requests) then
			-- The buffer is still in its window while these run.
			vim.schedule(check_edit_requests)
		end
	end,
	desc = "nvim-screen: finish edits opened from a terminal",
})

local wrapper = [=[
#!/usr/bin/env bash
# nvim wrapper installed by nvim-screen's init.lua: open files in the
# session this terminal belongs to instead of nesting another nvim.
real=@REAL@
[[ -x "$real" ]] || real=nvim

nested() { exec "$real" "$@"; }

[[ -n "$NVIM" && -z "$NVIM_SCREEN_NESTED" && -t 0 && -t 1 ]] || nested "$@"

q() { local s=${1//\'/\'\'}; printf "'%s'" "$s"; }

list="" only_files=""
for arg in "$@"; do
    if [[ -z "$only_files" && "$arg" == -* ]]; then
        if [[ "$arg" == "--" ]]; then
            only_files=1
        else
            nested "$@"
        fi
    fi
    list+="${list:+,}$(q "$arg")"
done

id=$("$real" --server "$NVIM" --remote-expr \
    "v:lua.NvimScreenEdit($(q "$PWD"), [$list])" 2>/dev/null)
[[ "$id" =~ ^[1-9][0-9]*$ ]] || nested "$@"

# Wait until the files are closed. Ends early if the session goes away.
while [[ $("$real" --server "$NVIM" --remote-expr \
    "v:lua.NvimScreenEditPending($id)" 2>/dev/null) == 1 ]]; do
    sleep 0.3
done
]=]

local function install_wrapper()
	-- Neovim's private temp dir: per server, removed when the server exits.
	local dir = vim.fn.fnamemodify(vim.fn.tempname(), ":h") .. "/nvim-screen-bin"
	vim.fn.mkdir(dir, "p")
	local path = dir .. "/nvim"
	local real = vim.fn.shellescape(vim.v.progpath)
	local text = wrapper:gsub("@REAL@", function()
		return real
	end)
	if vim.fn.writefile(vim.split(text, "\n", { plain = true }), path) ~= 0 then
		return
	end
	vim.fn.setfperm(path, "rwxr-xr-x")
	vim.env.NVIM_SCREEN_BIN = dir
	vim.env.PATH = dir .. ":" .. (vim.env.PATH or "")
end

install_wrapper()
