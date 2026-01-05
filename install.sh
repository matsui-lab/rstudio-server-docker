#!/bin/bash
# RStudio Server Docker - Web Installer Launcher
# Mac/Linux

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALLER_DIR="$SCRIPT_DIR/installer"

echo ""
echo "  RStudio Server Docker Installer"
echo "  ================================"
echo ""

# Check Node.js
if ! command -v node &> /dev/null; then
    echo "  Error: Node.js is not installed."
    echo ""
    echo "  Please install Node.js first:"
    echo "    - Mac:    brew install node"
    echo "    - Ubuntu: sudo apt install nodejs npm"
    echo "    - Or visit: https://nodejs.org/"
    echo ""
    exit 1
fi

NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 18 ]; then
    echo "  Warning: Node.js v18 or higher is recommended."
    echo "  Current version: $(node -v)"
    echo ""
fi

# Install dependencies if needed
if [ ! -d "$INSTALLER_DIR/node_modules" ]; then
    echo "  Installing dependencies..."
    cd "$INSTALLER_DIR"
    npm install
    echo ""
fi

# Start the installer
echo "  Starting installer..."
echo ""
cd "$INSTALLER_DIR"
npm start
