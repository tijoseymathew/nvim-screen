#!/usr/bin/env bash

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default locations
BIN_DIR="${HOME}/.local/bin"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvim-screen"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}nvim-screen installer${NC}"
echo

# Create directories if they don't exist
mkdir -p "$BIN_DIR"
mkdir -p "$CONFIG_DIR"

# Install the main script
echo -e "${BLUE}Installing nvim-screen to $BIN_DIR...${NC}"
cp "$SCRIPT_DIR/nvim-screen" "$BIN_DIR/nvim-screen"
chmod +x "$BIN_DIR/nvim-screen"
echo -e "${GREEN}✓${NC} Installed nvim-screen"

# Install config if it doesn't exist, or ask to overwrite
if [[ -f "$CONFIG_DIR/init.lua" ]]; then
    echo
    echo -e "${YELLOW}Config file already exists:${NC} $CONFIG_DIR/init.lua"
    read -p "Overwrite with default config? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cp "$SCRIPT_DIR/default-init.lua" "$CONFIG_DIR/init.lua"
        echo -e "${GREEN}✓${NC} Updated config file"
    else
        echo -e "${BLUE}→${NC} Keeping existing config"
    fi
else
    cp "$SCRIPT_DIR/default-init.lua" "$CONFIG_DIR/init.lua"
    echo -e "${GREEN}✓${NC} Installed default config to $CONFIG_DIR/init.lua"
fi

echo
echo -e "${GREEN}Installation complete!${NC}"
echo
echo -e "Usage:"
echo -e "  ${BLUE}nvim-screen${NC}           Start new session"
echo -e "  ${BLUE}nvim-screen -S name${NC}   Start named session"
echo -e "  ${BLUE}nvim-screen -ls${NC}       List sessions"
echo -e "  ${BLUE}nvim-screen -r${NC}        Attach to session"
echo
echo -e "Configuration:"
echo -e "  Edit: ${BLUE}$CONFIG_DIR/init.lua${NC}"
echo -e "  To disable quit interception, delete the config file"
echo

# Check if BIN_DIR is in PATH
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    echo -e "${YELLOW}Note:${NC} $BIN_DIR is not in your PATH"
    echo -e "Add this to your ~/.bashrc or ~/.zshrc:"
    echo -e "  ${BLUE}export PATH=\"\$HOME/.local/bin:\$PATH\"${NC}"
    echo
fi
