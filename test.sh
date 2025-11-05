#!/bin/bash
# Quick test script for styled-components.nvim

echo "🚀 Starting styled-components.nvim test environment..."
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if cssls is installed
if ! command -v vscode-css-language-server &>/dev/null; then
  echo "⚠️  WARNING: vscode-css-language-server not found!"
  echo "Install with: npm install -g vscode-langservers-extracted"
  echo ""
fi

# Run Neovim with test config
nvim -u "$SCRIPT_DIR/test/init_test.lua" "$SCRIPT_DIR/test/example.tsx"
