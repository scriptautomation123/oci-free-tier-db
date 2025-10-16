#!/bin/bash
# Ansible Virtual Environment Activation Helper
# This script activates the local Ansible virtual environment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VENV_DIR="${PROJECT_ROOT}/.venv"
ACTIVATE_SCRIPT="${VENV_DIR}/bin/activate"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Check if virtual environment exists
if [[ ! -d "$VENV_DIR" ]]; then
    print_error "Virtual environment not found at $VENV_DIR"
    print_info "Please run ./install-ansible.sh first to create the environment"
    exit 1
fi

if [[ ! -f "$ACTIVATE_SCRIPT" ]]; then
    print_error "Virtual environment activation script not found"
    print_info "Please run ./install-ansible.sh to recreate the environment"
    exit 1
fi

# Check if already in a virtual environment
if [[ -n "$VIRTUAL_ENV" ]]; then
    if [[ "$VIRTUAL_ENV" == "$VENV_DIR" ]]; then
        print_success "Already in the correct virtual environment"
    else
        print_warning "Currently in different virtual environment: $VIRTUAL_ENV"
        print_info "Switching to local Ansible environment..."
    fi
fi

# Activate the environment
print_info "Activating Ansible virtual environment..."
source "$ACTIVATE_SCRIPT"

# Verify activation
if [[ "$VIRTUAL_ENV" == "$VENV_DIR" ]]; then
    print_success "Virtual environment activated: $VIRTUAL_ENV"
    
    # Show available tools
    echo ""
    print_info "Available tools in this environment:"
    
    if command -v python &> /dev/null; then
        echo "  • Python: $(python --version 2>&1) ($(which python))"
    fi
    
    if command -v pip &> /dev/null; then
        echo "  • pip: $(pip --version | awk '{print $2}') ($(which pip))"
    fi
    
    if command -v ansible &> /dev/null; then
        echo "  • Ansible: $(ansible --version | head -n1 | awk '{print $3}' | tr -d ']') ($(which ansible))"
    else
        print_warning "Ansible not found - run ./install-ansible.sh to install"
    fi
    
    if command -v ansible-playbook &> /dev/null; then
        echo "  • ansible-playbook: $(which ansible-playbook)"
    fi
    
    echo ""
    print_info "To use Ansible commands, keep this shell session open"
    print_info "Or run: source $ACTIVATE_SCRIPT"
    echo ""
    print_info "Quick commands:"
    echo "  • Test setup: ansible-playbook ansible/playbooks/setup-environment.yml --check"
    echo "  • Deploy schema: ansible-playbook ansible/playbooks/local-complete.yml -e deployment_action=deploy"
    echo "  • Connect to DB: ./enhanced-connect-db.sh (after deployment)"
    
else
    print_error "Failed to activate virtual environment"
    exit 1
fi

# Start a new shell with the environment activated
print_info "Starting new shell with virtual environment activated..."
print_info "Type 'exit' to return to the original shell"
exec "$SHELL"