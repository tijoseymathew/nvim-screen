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

**Manual installation:**

```bash
# Install script only
curl -fsSL https://raw.githubusercontent.com/tijoseymathew/nvim-screen/main/nvim-screen -o ~/.local/bin/nvim-screen
chmod +x ~/.local/bin/nvim-screen

# Optionally install default config for quit interception
mkdir -p ~/.config/nvim-screen
curl -fsSL https://raw.githubusercontent.com/tijoseymathew/nvim-screen/main/init.lua -o ~/.config/nvim-screen/init.lua
```

## Usage

| Command | Description |
|---------|-------------|
| `nvim-screen` | Start new session (auto-named to current directory) |
| `nvim-screen -S <name>` | Start new session with name |
| `nvim-screen -ls` | List all sessions |
| `nvim-screen -r [name]` | Attach to session |
| `nvim-screen -d <name>` | Detach clients from session |
| `nvim-screen -h` | Show help |

Inside Neovim:
- `:detach` - detach from session
- `Ctrl-\ Ctrl-N` - alternative detach

## How it works

Uses Neovim's native client-server features:
- `nvim --listen` creates a session with a socket
- `nvim --remote-ui` attaches to existing session
- One socket file per session in `$XDG_RUNTIME_DIR/nvim-sessions-$USER/`

Single bash script. No dependencies beyond standard Unix tools.

## Configuration

nvim-screen can inject custom initialization code when starting sessions. The default config (installed to `~/.config/nvim-screen/init.lua`) provides quit interception to prevent accidentally closing sessions.

### Quit Interception (Default)

When you press `:q` in a nvim-screen session, you'll be prompted:
- **Detach** - Keep the session running in the background
- **Quit** - Actually close the session

This prevents accidentally closing a session when you meant to detach.

Commands available:
- `:q`, `:quit`, `:qa`, etc. - Prompts for detach vs quit
- `:q!` - Force quit (bypasses prompt)
- `:detach` - Explicitly detach (built-in nvim command)

### Customizing

The config file is installed at: `~/.config/nvim-screen/init.lua`

**To customize:**
```bash
# Edit the config directly
nvim ~/.config/nvim-screen/init.lua
```

**To disable quit interception:**
```bash
# Just delete the config file
rm ~/.config/nvim-screen/init.lua
```

The init script is pure Lua with full access to Neovim's API. Add any custom initialization code you want.

## Requirements

- Neovim 0.9+ (for `--remote-ui` and client-server features)
- Bash

## Coming soon

- Remote session support with easy port forwarding
- Shell completion (bash/zsh)

## Philosophy

- **Single script**: No package managers, no complex installation
- **Familiar interface**: GNU screen commands you already know
- **Minimal**: Uses Neovim's native features, no hidden magic
- **Respects your setup**: Optional enhancements only, never overrides config

## License

MIT
