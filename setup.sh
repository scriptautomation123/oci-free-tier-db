#!/bin/bash
# Quick launcher for local development setup
# This script provides easy access to local development tools

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_INSTALL_DIR="$SCRIPT_DIR/local-install"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}🚀 OCI Free Tier Database Suite - Local Development${NC}"
echo ""

if [[ ! -d "$LOCAL_INSTALL_DIR" ]]; then
    echo -e "${YELLOW}⚠️  local-install directory not found${NC}"
    exit 1
fi

# Check if already set up
if [[ -d "$SCRIPT_DIR/.venv" ]] && [[ -f "$SCRIPT_DIR/.venv/bin/activate" ]]; then
    echo -e "${GREEN}✅ Development environment already set up${NC}"
    echo ""
    echo "Available options:"
    echo "  1. Activate environment: source ./dev-env.sh"
    echo "  2. Validate environment: local-install/env-validate.sh"
    echo "  3. Configure Terraform: local-install/setup-env-vars.sh"
    echo "  4. Reinstall everything: local-install/setup-local-dev.sh"
    echo ""
    
    read -p "Run quick environment activation? (y/N): " activate
    if [[ "$activate" =~ ^[Yy]$ ]]; then
        echo ""
        echo "Run: source ./dev-env.sh"
    fi
else
    echo -e "${YELLOW}🔧 Setting up development environment for the first time...${NC}"
    echo ""
    cd "$LOCAL_INSTALL_DIR"
    ./setup-local-dev.sh
fi