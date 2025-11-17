#!/usr/bin/env bash

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# GitHub repository details
GITHUB_BRANCH="main"
BASE_URL="https://raw.githubusercontent.com/tijoseymathew/nvim-screen/${GITHUB_BRANCH}"

# Default locations
BIN_DIR="${HOME}/.local/bin"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvim-screen"

echo -e "${BLUE}nvim-screen installer${NC}"
echo

# Check for required commands
if ! command -v curl &> /dev/null; then
    echo -e "${RED}Error: curl is required but not installed.${NC}"
    exit 1
fi

# Create directories if they don't exist
mkdir -p "$BIN_DIR"
mkdir -p "$CONFIG_DIR"

# Download and install the main script
echo -e "${BLUE}Downloading nvim-screen...${NC}"
if curl -fsSL "${BASE_URL}/nvim-screen" -o "$BIN_DIR/nvim-screen"; then
    chmod +x "$BIN_DIR/nvim-screen"
    echo -e "${GREEN}✓${NC} Installed nvim-screen to $BIN_DIR/nvim-screen"
else
    echo -e "${RED}✗${NC} Failed to download nvim-screen"
    exit 1
fi

# Install config if it doesn't exist, or ask to overwrite
if [[ -f "$CONFIG_DIR/init.lua" ]]; then
    echo
    echo -e "${YELLOW}Config file already exists:${NC} $CONFIG_DIR/init.lua"
    read -p "Overwrite with default config? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if curl -fsSL "${BASE_URL}/init.lua" -o "$CONFIG_DIR/init.lua"; then
            echo -e "${GREEN}✓${NC} Updated config file"
        else
            echo -e "${RED}✗${NC} Failed to download config file"
            exit 1
        fi
    else
        echo -e "${BLUE}→${NC} Keeping existing config"
    fi
else
    echo -e "${BLUE}Downloading default config...${NC}"
    if curl -fsSL "${BASE_URL}/init.lua" -o "$CONFIG_DIR/init.lua"; then
        echo -e "${GREEN}✓${NC} Installed default config to $CONFIG_DIR/init.lua"
    else
        echo -e "${RED}✗${NC} Failed to download config file"
        exit 1
    fi
fi

echo
echo -e "${GREEN}Installation complete!${NC}"
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
