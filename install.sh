#!/usr/bin/env bash

# nvim-screen installer
#
# Installs from the 'main' branch of tijoseymathew/nvim-screen by default.
# Override either with an environment variable -- no need to edit this file:
#
#   GITHUB_BRANCH=my-feature ./install.sh
#   curl -fsSL <raw-url>/install.sh | GITHUB_BRANCH=my-feature bash
#   curl -fsSL <raw-url>/install.sh | GITHUB_REPO=you/nvim-screen bash
#
# Note the placement when piping: 'VAR=x curl ... | bash' sets VAR for curl,
# not for the shell running the script.
#
# Other variables:
#   NVIM_SCREEN_OVERWRITE_CONFIG=1  overwrite an existing init.lua without asking

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# GitHub repository details
GITHUB_REPO="${GITHUB_REPO:-tijoseymathew/nvim-screen}"
GITHUB_BRANCH="${GITHUB_BRANCH:-main}"
BASE_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/${GITHUB_BRANCH}"

# Default locations
BIN_DIR="${HOME}/.local/bin"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvim-screen"
COMPLETION_DIR="${HOME}/.local/share/bash-completion/completions"

echo -e "${BLUE}nvim-screen installer${NC}"
echo -e "Source: ${BLUE}${GITHUB_REPO}${NC} @ ${BLUE}${GITHUB_BRANCH}${NC}"
echo

# Check for required commands
if ! command -v curl &> /dev/null; then
    echo -e "${RED}Error: curl is required but not installed.${NC}"
    exit 1
fi

# Temp file of an in-flight download, removed if the installer is interrupted
DOWNLOAD_TMP=""
trap 'rm -f "$DOWNLOAD_TMP" 2>/dev/null || true' EXIT

# Fetch a file into place. Downloads to a temp file first: 'curl -o' truncates
# its target before it knows whether the transfer will succeed, so a network
# failure partway through would leave an empty or half-written nvim-screen
# where a working one used to be. The temp file lives in the destination
# directory - $TMPDIR may be a different filesystem, and a cross-filesystem
# mv is a truncate-and-copy, not the atomic rename this relies on.
download() {
    local remote_path="$1" dest="$2" tmp

    tmp=$(mktemp "${dest}.XXXXXX") || return 1
    DOWNLOAD_TMP="$tmp"
    if ! curl -fsSL "${BASE_URL}/${remote_path}" -o "$tmp" || [[ ! -s "$tmp" ]]; then
        rm -f "$tmp"
        DOWNLOAD_TMP=""
        return 1
    fi
    chmod 644 "$tmp"  # mktemp creates 0600; these are ordinary shared-read files
    mv -f "$tmp" "$dest"
    DOWNLOAD_TMP=""
}

# True when there is a terminal we can prompt on. The /dev/tty node exists
# even with no controlling terminal attached and only fails at open time, so
# a '-e'/'-r' test is not enough - probe it by opening it in a subshell.
has_tty() {
    ( : < /dev/tty ) 2>/dev/null
}

# Ask a yes/no question, defaulting to no.
#
# Reads from /dev/tty rather than stdin: under 'curl ... | bash' stdin is the
# installer's own source, so a plain 'read' would consume the rest of the
# script instead of waiting for the user.
confirm() {
    local prompt="$1" reply=""

    has_tty || return 1
    read -r -n 1 -p "$prompt" reply < /dev/tty || return 1
    echo
    [[ "$reply" =~ ^[Yy]$ ]]
}

# Create directories if they don't exist
mkdir -p "$BIN_DIR"
mkdir -p "$CONFIG_DIR"
mkdir -p "$COMPLETION_DIR"

# Download and install the main script
echo -e "${BLUE}Downloading nvim-screen...${NC}"
if download "nvim-screen" "$BIN_DIR/nvim-screen"; then
    chmod +x "$BIN_DIR/nvim-screen"
    echo -e "${GREEN}✓${NC} Installed nvim-screen to $BIN_DIR/nvim-screen"
else
    echo -e "${RED}✗${NC} Failed to download nvim-screen"
    echo -e "  Check that branch '${GITHUB_BRANCH}' exists in ${GITHUB_REPO}"
    exit 1
fi

# Install config if it doesn't exist, or ask to overwrite
if [[ -f "$CONFIG_DIR/init.lua" ]]; then
    echo
    echo -e "${YELLOW}Config file already exists:${NC} $CONFIG_DIR/init.lua"
    if [[ "${NVIM_SCREEN_OVERWRITE_CONFIG:-0}" == "1" ]] \
        || confirm "Overwrite with default config? [y/N] "; then
        if download "init.lua" "$CONFIG_DIR/init.lua"; then
            echo -e "${GREEN}✓${NC} Updated config file"
        else
            echo -e "${RED}✗${NC} Failed to download config file"
            exit 1
        fi
    else
        echo -e "${BLUE}→${NC} Keeping existing config"
        if ! has_tty; then
            echo -e "  Re-run with ${BLUE}NVIM_SCREEN_OVERWRITE_CONFIG=1${NC} to replace it"
        fi
    fi
else
    echo -e "${BLUE}Downloading default config...${NC}"
    if download "init.lua" "$CONFIG_DIR/init.lua"; then
        echo -e "${GREEN}✓${NC} Installed default config to $CONFIG_DIR/init.lua"
    else
        echo -e "${RED}✗${NC} Failed to download config file"
        exit 1
    fi
fi

# Install bash completion
echo
echo -e "${BLUE}Downloading bash completion...${NC}"
if download "bash-completion.sh" "$COMPLETION_DIR/nvim-screen"; then
    echo -e "${GREEN}✓${NC} Installed bash completion to $COMPLETION_DIR/nvim-screen"
else
    echo -e "${YELLOW}⚠${NC} Failed to download bash completion (non-fatal)"
fi

# Sanity check: a truncated or HTML error page would install cleanly but not run
echo
if version_output=$("$BIN_DIR/nvim-screen" -v 2>/dev/null); then
    echo -e "${GREEN}Installation complete!${NC} ($version_output)"
else
    echo -e "${RED}✗${NC} Installed nvim-screen does not run - the download may be corrupt"
    exit 1
fi
echo
echo -e "Run ${BLUE}nvim-screen -h${NC} for usage information"
echo

# Check if BIN_DIR is in PATH
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    echo -e "${YELLOW}Note:${NC} $BIN_DIR is not in your PATH"
    echo -e "Add this to your ~/.bashrc or ~/.zshrc:"
    echo -e "  ${BLUE}export PATH=\"\$HOME/.local/bin:\$PATH\"${NC}"
    echo
fi

# Bash completion note
echo -e "${YELLOW}Note:${NC} To enable bash completions, restart your shell or run:"
echo -e "  ${BLUE}source $COMPLETION_DIR/nvim-screen${NC}"
echo

# SSH multiplexing recommendation.
#
# nvim-screen used to start and manage a control master per host. It doesn't
# any more - that belongs in the user's own ssh config, where every other ssh
# caller benefits from it too - so tell them how to set it up. Remote sessions
# work without it; they just re-authenticate on every command.
ssh_multiplexing_configured() {
    local f
    for f in "$HOME/.ssh/config" /etc/ssh/ssh_config; do
        [[ -r "$f" ]] || continue
        grep -qiE '^[[:space:]]*ControlMaster[[:space:]]+(auto|yes)' "$f" && return 0
    done
    # Included files are common enough that a ControlPath anywhere counts
    if [[ -d "$HOME/.ssh/config.d" ]]; then
        grep -rqiE '^[[:space:]]*ControlMaster[[:space:]]+(auto|yes)' "$HOME/.ssh/config.d" 2>/dev/null && return 0
    fi
    return 1
}

if ssh_multiplexing_configured; then
    echo -e "${GREEN}✓${NC} SSH connection multiplexing is already configured"
    echo -e "  Remote sessions will reuse a single authenticated connection"
    echo
else
    echo -e "${YELLOW}Recommended:${NC} enable SSH connection multiplexing"
    echo
    echo -e "nvim-screen does not manage SSH control masters itself - it uses"
    echo -e "whatever your ${BLUE}~/.ssh/config${NC} says. Remote sessions work without this,"
    echo -e "but every remote command re-authenticates. Adding it also speeds up"
    echo -e "${BLUE}scp${NC}, ${BLUE}rsync${NC} and ${BLUE}git${NC} over SSH, and the ${BLUE}ServerAlive${NC} settings are what make a"
    echo -e "dropped connection get noticed in seconds instead of minutes."
    echo
    echo -e "Add to ${BLUE}~/.ssh/config${NC}:"
    echo
    echo -e "${BLUE}  Host *${NC}"
    echo -e "${BLUE}      ControlMaster auto${NC}"
    echo -e "${BLUE}      ControlPath ~/.ssh/sockets/%r@%h:%p${NC}"
    echo -e "${BLUE}      ControlPersist 10m${NC}"
    echo -e "${BLUE}      ServerAliveInterval 15${NC}"
    echo -e "${BLUE}      ServerAliveCountMax 3${NC}"
    echo
    echo -e "Then create the socket directory:"
    echo -e "${BLUE}  mkdir -p ~/.ssh/sockets && chmod 700 ~/.ssh/sockets${NC}"
    echo
fi
