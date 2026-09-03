# nvim-screen

GNU screen-style session management for Neovim.

## Why?

Neovim has a built-in terminal. You can edit code and run commands in the same interface. So why layer tmux on top?

The terminal-in-editor workflow is simpler:
- No tmux prefix key conflicts
- Native splits and navigation  
- One less abstraction layer
- Everything in the same keybinding space

But sessions matter. You need to detach from work and come back later, keep builds running after closing terminal, switch between projects. That's what GNU screen solved decades ago. This brings that pattern to Neovim.

**tmux + vim = nvim-screen**

## Installation

**Quick install (recommended):**

```bash
curl -fsSL https://raw.githubusercontent.com/tijoseymathew/nvim-screen/main/install.sh | bash
```

This installs:
- `nvim-screen` to `~/.local/bin/`
- Default config to `~/.config/nvim-screen/init.lua`
- Bash completions to `~/.local/share/bash-completion/completions/`

**Installing a different branch or fork:**

The installer reads `GITHUB_BRANCH` (default `main`) and `GITHUB_REPO`
(default `tijoseymathew/nvim-screen`) from the environment:

```bash
curl -fsSL https://raw.githubusercontent.com/tijoseymathew/nvim-screen/main/install.sh \
    | GITHUB_BRANCH=my-feature bash
```

Note where the variable goes: `GITHUB_BRANCH=x curl ... | bash` would set it
for `curl`, not for the shell running the installer. When running a local
copy, the usual prefix works: `GITHUB_BRANCH=my-feature ./install.sh`.

Set `NVIM_SCREEN_OVERWRITE_CONFIG=1` to replace an existing
`init.lua` without being prompted (the installer keeps it by default when
there is no terminal to ask on).

**Manual installation:**

```bash
# Install script only
curl -fsSL https://raw.githubusercontent.com/tijoseymathew/nvim-screen/main/nvim-screen -o ~/.local/bin/nvim-screen
chmod +x ~/.local/bin/nvim-screen

# Optionally install default config for quit interception
mkdir -p ~/.config/nvim-screen
curl -fsSL https://raw.githubusercontent.com/tijoseymathew/nvim-screen/main/init.lua -o ~/.config/nvim-screen/init.lua
```

Remote hosts don't need any of this — connecting with `-s` installs
nvim-screen there automatically (see below).

## Usage

| Command | Description |
|---------|-------------|
| `nvim-screen` | Start new session (auto-named to current directory) |
| `nvim-screen -S <name>` | Start new session with name |
| `nvim-screen -ls` | List all sessions (local and remote) |
| `nvim-screen -r [name]` | Attach to session (`host:name` for remote) |
| `nvim-screen -d <name>` | Detach all clients from session |
| `nvim-screen -k <name>` | Kill (terminate) session |
| `nvim-screen -c <dir>` | Start session in a working directory (local or remote) |
| `nvim-screen -s <host> ...` | Run any of the above on a remote host |
| `nvim-screen -s <host> -sync` | Push Neovim, your config, and nvim-screen to host |
| `nvim-screen -fix` | Restore a terminal left garbled by a dead session |
| `nvim-screen -h` | Show help |

Inside Neovim:
- `:q`, `:qa`, `:wq`, `ZZ`, ... — detach when the quit would end the session;
  otherwise they close the window as usual
- `:Detach` — detach all clients explicitly
- `:Quit` — actually end the session

## How it works

Uses Neovim's native client-server features:
- Each session is a **headless** `nvim --listen` server, detached from your
  terminal, so it survives client exits, terminal crashes, and dropped SSH
  connections
- Your terminal attaches to it as a `nvim --remote-ui` client
- Detaching just closes the client channel — the server keeps running
- One socket file per session in `$XDG_RUNTIME_DIR/nvim-sessions-$USER/`

Single bash script. No dependencies beyond standard Unix tools.

### Quit interception

The default config (`~/.config/nvim-screen/init.lua`) rewrites quit commands
on the command line before they execute (`QuitPre`/`ExitPre` autocommands
cannot abort an exit, so rewriting is the only reliable interception point):

- A quit that only closes a window or tab runs unchanged
- A quit that would end the session (`:q` on the last window, `:qa`, `ZZ`, ...)
  writes files if asked (`:wq`, `:x`) and then **detaches** instead
- `:Quit` (or `nvim-screen -k <name>` from the shell) ends the session for real

To disable, delete the config file. The init script is pure Lua with full
access to Neovim's API — add any custom session initialization you want.
`$NVIM_SCREEN_SESSION` holds the session name inside the server (useful for
statuslines).

## Remote sessions

```bash
nvim-screen -s user@host -S myproj      # start a session on host and attach
nvim-screen -s user@host -c ~/work/app  # start it in a remote directory
nvim-screen -s user@host -ls            # list sessions on host
nvim-screen -r user@host:myproj         # attach to a remote session
nvim-screen -k user@host:myproj         # kill a remote session
```

- Connections are plain `ssh`. Whether repeated commands re-authenticate is
  decided by **your** `~/.ssh/config` — nvim-screen no longer runs a control
  master of its own (see [Connection multiplexing](#connection-multiplexing))
- If nvim-screen isn't installed on the host, it is **installed automatically**
  on first connect (the script and your nvim-screen config are pushed over the
  existing SSH connection — the remote only needs Neovim 0.9+), and it is
  re-pushed whenever the remote version differs from yours
- `-sync` additionally pushes your `~/.config/nvim` to the host, so your
  editor config follows you (plugins are installed by your plugin manager on
  first run) — and if the host has no Neovim at all, it installs the official
  stable build into `~/.local` there, no root required
- `-c <dir>` sets the session's working directory; when a control master for
  the host is already up, bash completion completes **remote** directories
- `nvim-screen -ls` lists local sessions and sessions on every host you have
  connected to in this boot; each host is asked non-interactively and with a
  time limit, so an unreachable one is skipped rather than hanging the listing

### Connection multiplexing

nvim-screen used to start and manage an SSH control master per host. It no
longer does: multiplexing is a property of the connection, not of this tool,
and configuring it yourself means `scp`, `rsync`, `git` and everything else
benefit from the same connection reuse.

Put this in `~/.ssh/config`:

```
Host *
    ControlMaster auto
    ControlPath ~/.ssh/sockets/%r@%h:%p
    ControlPersist 10m
    ServerAliveInterval 15
    ServerAliveCountMax 3
```

```bash
mkdir -p ~/.ssh/sockets
```

Without it, nothing breaks — each remote command just authenticates on its
own. With it, the first connection carries every one that follows, and
`ServerAlive*` is what makes a dropped link get noticed in seconds rather
than minutes. The installer prints the same snippet.

## Troubleshooting

**Terminal prints garbage after a dropped SSH connection.** When the
connection dies while nvim owns the screen, the terminal emulator is left in
modes nvim never got to switch off — the kitty keyboard protocol (every
keypress then prints `[27u`-style sequences, which is also why typing
`reset` into the wreckage often goes nowhere), mouse reporting, bracketed
paste, the alternate screen. nvim-screen restores all of this automatically
the moment `ssh` returns, and the session itself keeps running server-side —
just reattach with `nvim-screen -r host:name`.

If a terminal is already stuck (older nvim-screen, or the process was
force-killed before its cleanup could run), run `nvim-screen -fix` in it.
The keystrokes may echo as garbage, but they still reach the shell — press
Enter and the command runs.

## Requirements

- Neovim 0.9+ (for `--remote-ui` and client-server features)
- Bash
- OpenSSH client (for remote sessions)

## Features

- Bash completions for commands and session names
- Tab completion for SSH hosts from your SSH config

## Philosophy

- **Single script**: No package managers, no complex installation
- **Familiar interface**: GNU screen commands you already know
- **Minimal**: Uses Neovim's native features, no hidden magic
- **Respects your setup**: Optional enhancements only, never overrides config

## License

MIT
