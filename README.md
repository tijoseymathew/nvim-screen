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

# Optionally install default config for the screen-style detach binding
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
- `Ctrl+a` `d` — detach; the session keeps running (GNU screen's binding)
- `Ctrl+a` `a` — send a literal `Ctrl+a`
- `:Detach` — the same thing from the command line
- `:q`, `:qa`, `:wq`, `ZZ`, ... — ordinary Neovim quits; the last one ends the
  session, exactly as they would outside nvim-screen

## How it works

Uses Neovim's native client-server features:
- Each session is a **headless** `nvim --listen` server, detached from your
  terminal, so it survives client exits, terminal crashes, and dropped SSH
  connections
- Your terminal attaches to it as a `nvim --remote-ui` client
- Detaching just closes the client channel — the server keeps running
- One socket file per session in `$XDG_RUNTIME_DIR/nvim-sessions-$USER/`

Single bash script. No dependencies beyond standard Unix tools.

### Detaching

The default config (`~/.config/nvim-screen/init.lua`) adds a prefix key in
GNU screen's style. `Ctrl+a` then `d` detaches: the client goes away, the
session and everything running in it stay.

- `Ctrl+a` `d` — detach
- `Ctrl+a` `a` — send a literal `Ctrl+a` (screen's escape convention), so the
  increment command is still one keystroke away
- `:Detach` — same action, for when your hands are already on `:`
- bare `Ctrl+a` is left unmapped, so after `timeoutlen` it still increments
  the number under the cursor
- `NVIM_SCREEN_PREFIX` changes the prefix (Neovim key notation, e.g.
  `NVIM_SCREEN_PREFIX='<C-b>'`); nvim-screen passes it to the session, local
  or remote

Quit commands are not intercepted: `:q`, `:qa`, `:wq` and `ZZ` mean what they
always mean, and the last one ends the session — as does
`nvim-screen -k <name>` from the shell.

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

### When the connection drops

Your session lives on the host, not in the connection, so nothing is lost —
but the terminal you were typing into has to come back. Two things make sure
it does.

**The dead link gets noticed.** Left alone, `ssh` sits in a TCP retransmit
loop for minutes after the network goes away, and for all of those minutes
your terminal is frozen inside Neovim's alternate screen with no way out.
So the connection is supervised:

- on a connection nvim-screen opens itself, `ServerAliveInterval`/
  `ServerAliveCountMax` make it give up in about 45s
- on a connection multiplexed over your control master, those are the
  master's business, and a watchdog beside the attached session notices when
  the master dies (or is alive but no longer carrying anything) and drops you
  back to your shell
- `Enter` `~` `.` — ssh's own escape — works at any time, and never waits

**The terminal gets put back.** Raw mode, the alternate screen, mouse
reporting, bracketed paste, focus reporting, the kitty keyboard protocol,
`modifyOtherKeys`, the scrolling region, auto-wrap and the alternate
character sets are all unwound on every exit path — clean detach, killed
client, dropped link, or a signal to nvim-screen itself. Your terminal
settings are restored to exactly what they were; the screen and scrollback
are deliberately left alone (no `tput reset`, no RIS). The reset is written
to `/dev/tty`, so it lands even when output was redirected.

Reattaching evicts any client that is still attached: Neovim sizes the
screen to the smallest attached UI, so a leftover client from a dropped
connection is what makes a reattached session look mangled. Set
`NVIM_SCREEN_SHARE=1` to attach alongside existing clients instead.

Environment knobs: `NVIM_SCREEN_KEEPALIVE_INTERVAL` (15),
`NVIM_SCREEN_KEEPALIVE_COUNT` (3), `NVIM_SCREEN_WATCHDOG` (1, set to 0 to
disable), `NVIM_SCREEN_WATCHDOG_TICK` (3), `NVIM_SCREEN_DEEP_PROBE_EVERY`
(10 ticks, 0 disables), `NVIM_SCREEN_SSH_DIRECT` (1 forces an unmultiplexed
connection so this client handles escapes and keepalives itself).

## Troubleshooting

**Terminal prints garbage after a dropped SSH connection.** Run
`nvim-screen -fix` in it. The keystrokes may echo as garbage, but they still
reach the shell — press Enter and the command runs. This should not be
needed for a session nvim-screen was supervising (see
[When the connection drops](#when-the-connection-drops)); it is there for a
terminal wrecked some other way — an older nvim-screen, a force-quit
emulator, or a full-screen program that was not nvim-screen at all.

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
