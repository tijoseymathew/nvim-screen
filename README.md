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

- Connections are multiplexed over a persistent SSH control master, so
  repeated commands don't re-authenticate
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
- `nvim-screen -ls` lists local sessions and sessions on every connected host

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
