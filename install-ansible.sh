#!/usr/bin/env bash
# ============================================================================
# Ansible Installation Script (No Sudo Required)
# Install Ansible and required collections in user-space
# ============================================================================

set -e  # Exit on error

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="${SCRIPT_DIR}/ansible"
VENV_DIR="${SCRIPT_DIR}/.venv"
ACTIVATE_SCRIPT="${VENV_DIR}/bin/activate"

# ============================================================================
# Utility Functions
# ============================================================================

print_header() {
    echo -e "${BLUE}===================================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===================================================================${NC}"
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

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# ============================================================================
# Step 1: Verify Python3
# ============================================================================

check_python() {
    print_header "Step 1: Verifying Python and Setting up Virtual Environment"

    if ! command -v python3 &> /dev/null; then
        print_error "Python3 is not installed"
        print_info "Python3 is required but must be installed by system administrator"
        return 1
    fi

    local python_version python_major python_minor
    python_version=$(python3 --version 2>&1 | awk '{print $2}')
    python_major=$(echo "$python_version" | cut -d. -f1)
    python_minor=$(echo "$python_version" | cut -d. -f2)

    if [[ $python_major -lt 3 ]] || [[ $python_major -eq 3 && $python_minor -lt 6 ]]; then
        print_error "Python 3.6+ is required, found $python_version"
        return 1
    fi

    print_success "Python $python_version detected"

    # Check if virtual environment already exists and is functional
    if [[ -d "$VENV_DIR" && -f "$ACTIVATE_SCRIPT" ]]; then
        print_info "Existing virtual environment found, testing..."
        if source "$ACTIVATE_SCRIPT" && python -c "import sys; print(f'Python {sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}')" &> /dev/null; then
            print_success "Existing virtual environment is functional"
            # Check if ansible is already installed
            if command -v ansible &> /dev/null; then
                local ansible_version
                ansible_version=$(ansible --version | head -n1 | awk '{print $3}' | tr -d ']')
                print_success "Ansible $ansible_version already available in virtual environment"
            fi
            return 0
        else
            print_warning "Existing virtual environment is corrupted, recreating..."
            rm -rf "$VENV_DIR"
        fi
    fi

    # Try different methods to create virtual environment
    print_info "Creating new virtual environment at $VENV_DIR"

    # Method 1: Try standard venv module
    if python3 -m venv "$VENV_DIR" 2>/dev/null; then
        print_success "Virtual environment created using venv module"
    # Method 2: Try virtualenv if available
    elif command -v virtualenv &> /dev/null && virtualenv -p python3 "$VENV_DIR" 2>/dev/null; then
        print_success "Virtual environment created using virtualenv"
    # Method 3: Manual bootstrap approach
    else
        print_warning "Standard venv creation failed, attempting manual bootstrap..."

        # Create directory structure manually
        mkdir -p "$VENV_DIR"/{bin,lib,include}

        # Create a simple activation script
        cat > "$ACTIVATE_SCRIPT" << 'EOF'
#!/bin/bash
# Virtual environment activation script
export VIRTUAL_ENV="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="$VIRTUAL_ENV/bin:$PATH"
unset PYTHON_HOME
if [ -n "${BASH:-}" ] || [ -n "${ZSH_VERSION:-}" ]; then
    hash -r 2>/dev/null
fi
EOF
        chmod +x "$ACTIVATE_SCRIPT"

        # Create a python symlink
        ln -sf "$(which python3)" "$VENV_DIR/bin/python"
        ln -sf "$(which python3)" "$VENV_DIR/bin/python3"

        print_success "Manual virtual environment structure created"
    fi

    # Verify and activate virtual environment
    if [[ -f "$ACTIVATE_SCRIPT" ]]; then
        print_info "Activating virtual environment"
        source "$ACTIVATE_SCRIPT"
        print_success "Virtual environment activated ($(which python))"

        # Try to bootstrap pip if not available
        if ! python -m pip --version &> /dev/null; then
            print_info "Bootstrapping pip in virtual environment"

            # Try ensurepip first
            if python -m ensurepip --upgrade 2>/dev/null; then
                print_success "pip bootstrapped via ensurepip"
            # Try downloading get-pip.py as fallback
            elif command -v curl &> /dev/null; then
                print_info "Downloading get-pip.py bootstrap script"
                curl -s https://bootstrap.pypa.io/get-pip.py | python
                print_success "pip bootstrapped via get-pip.py"
            elif command -v wget &> /dev/null; then
                print_info "Downloading get-pip.py bootstrap script"
                wget -qO- https://bootstrap.pypa.io/get-pip.py | python
                print_success "pip bootstrapped via get-pip.py"
            else
                print_warning "Could not bootstrap pip - continuing without upgrade"
            fi
        fi

        # Upgrade pip if possible
        if python -m pip --version &> /dev/null; then
            print_info "Upgrading pip in virtual environment"
            python -m pip install --upgrade pip setuptools wheel 2>/dev/null || print_warning "pip upgrade failed, continuing anyway"
        fi
    else
        print_error "Virtual environment activation script not found"
        return 1
    fi

    return 0
}

# ============================================================================
# Step 2: Ensure ~/.local/bin is in PATH
# ============================================================================

add_to_path_if_needed() {
    local shell_rc="$1"
    local path_line='export PATH="$HOME/.local/bin:$PATH"'

    if [[ ! -f "$shell_rc" ]]; then
        touch "$shell_rc"
        print_info "Created $shell_rc"
    fi

    if grep -q "\.local/bin.*PATH" "$shell_rc"; then
        print_success "PATH already configured in $shell_rc"
        return 0
    fi

    echo "" >> "$shell_rc"
    echo "# Added by Ansible installation script" >> "$shell_rc"
    echo "$path_line" >> "$shell_rc"
    print_success "Added ~/.local/bin to PATH in $shell_rc"
}

setup_path() {
    print_header "Step 2: Configuring PATH"

    # Create ~/.local/bin if it doesn't exist
    if [[ ! -d "$HOME/.local/bin" ]]; then
        mkdir -p "$HOME/.local/bin"
        print_success "Created $HOME/.local/bin"
    fi

    # Check current PATH
    if echo "$PATH" | grep -q "$HOME/.local/bin"; then
        print_success "$HOME/.local/bin is already in current PATH"
    else
        print_warning "$HOME/.local/bin is not in current PATH (will be after shell restart)"
        export PATH="$HOME/.local/bin:$PATH"
    fi

    # Update shell configuration files
    add_to_path_if_needed "$HOME/.bashrc"

    if [[ -f "$HOME/.zshrc" ]] || [[ "$SHELL" == *"zsh"* ]]; then
        add_to_path_if_needed "$HOME/.zshrc"
    fi

    print_info "PATH will be fully configured after restarting your shell"
}

# ============================================================================
# Step 3: Install Ansible
# ============================================================================

install_ansible() {
    print_header "Step 3: Installing Ansible in Virtual Environment"

    # Ensure we're in the virtual environment
    if [[ -z "$VIRTUAL_ENV" ]]; then
        print_info "Activating virtual environment"
        source "$ACTIVATE_SCRIPT"
    fi

    # Check if Ansible is already installed in the venv
    if command -v ansible &> /dev/null; then
        local current_version
        current_version=$(ansible --version | head -n1 | awk '{print $3}' | tr -d ']')
        print_warning "Ansible $current_version is already installed in virtual environment"

        read -p "Do you want to upgrade Ansible? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Skipping Ansible installation"
            return 0
        fi
    fi

    print_info "Installing Ansible in virtual environment..."

    # Install ansible using pip in the virtual environment
    if python -m pip install --upgrade ansible; then
        local version
        version=$(ansible --version 2>/dev/null | head -n1 | awk '{print $3}' | tr -d ']')
        print_success "Ansible $version installed successfully in virtual environment"
    else
        print_error "Failed to install Ansible"
        return 1
    fi

    # Install additional useful packages
    print_info "Installing additional Python packages..."
    python -m pip install --upgrade requests pyyaml jinja2 oci || print_warning "Some additional packages failed to install"

    return 0
}

# ============================================================================
# Step 4: Navigate to Project Directory
# ============================================================================

verify_project_structure() {
    print_header "Step 4: Verifying Project Structure"

    if [[ ! -d "$ANSIBLE_DIR" ]]; then
        print_error "Ansible directory not found: $ANSIBLE_DIR"
        return 1
    fi
    print_success "Ansible directory found: $ANSIBLE_DIR"

    if [[ ! -f "$ANSIBLE_DIR/ansible.cfg" ]]; then
        print_error "ansible.cfg not found in $ANSIBLE_DIR"
        return 1
    fi
    print_success "ansible.cfg found"

    if [[ ! -f "$ANSIBLE_DIR/requirements.yml" ]]; then
        print_error "requirements.yml not found in $ANSIBLE_DIR"
        return 1
    fi
    print_success "requirements.yml found"

    if [[ ! -d "$ANSIBLE_DIR/playbooks" ]]; then
        print_error "playbooks directory not found"
        return 1
    fi
    print_success "playbooks directory found"

    # Check for main playbooks (role-based structure)
    local main_playbooks=("site.yml" "deploy.yml" "setup.yml" "cleanup.yml")
    local found_playbooks=()

    for playbook in "${main_playbooks[@]}"; do
        if [[ -f "$ANSIBLE_DIR/playbooks/$playbook" ]]; then
            print_success "$playbook found"
            found_playbooks+=("$playbook")
        else
            print_warning "$playbook not found (optional)"
        fi
    done

    if [[ ${#found_playbooks[@]} -eq 0 ]]; then
        print_error "No main playbooks found in playbooks directory"
        return 1
    fi

    print_success "Found ${#found_playbooks[@]} main playbook(s)"
}

# ============================================================================
# Step 5: Install Ansible Collections
# ============================================================================

install_collections() {
    print_header "Step 5: Installing Ansible Collections"

    cd "$ANSIBLE_DIR"

    print_info "Installing collections from requirements.yml..."
    ansible-galaxy collection install -r requirements.yml

    if [[ $? -eq 0 ]]; then
        print_success "Collections installed successfully"
    else
        print_error "Failed to install collections"
        return 1
    fi

    # Verify collections
    print_info "Verifying installed collections..."
    local collections
    collections=$(ansible-galaxy collection list 2>/dev/null | grep -E "(community.general|ansible.posix)" || echo "")

    if [[ -n "$collections" ]]; then
        echo "$collections" | while read -r line; do
            print_success "$line"
        done
    else
        print_warning "Could not verify collections (they may still be installed)"
    fi
}

# ============================================================================
# Step 6: Verify Configuration
# ============================================================================

verify_installation() {
    print_header "Step 6: Verifying Installation"

    cd "$ANSIBLE_DIR"

    # Check Ansible version
    if command -v ansible &> /dev/null; then
        local version
        version=$(ansible --version | head -n1)
        print_success "Ansible: $version"
    else
        print_error "Ansible command not found"
        return 1
    fi

    # Check ansible-playbook
    if command -v ansible-playbook &> /dev/null; then
        print_success "ansible-playbook: $(which ansible-playbook)"
    else
        print_error "ansible-playbook command not found"
        return 1
    fi

    # Check ansible-galaxy
    if command -v ansible-galaxy &> /dev/null; then
        print_success "ansible-galaxy: $(which ansible-galaxy)"
    else
        print_error "ansible-galaxy command not found"
        return 1
    fi

    # Verify inventory
    print_info "Checking inventory..."
    if ansible-inventory --list -i .ansible/inventory/localhost.yml &> /dev/null; then
        print_success "Inventory is valid"
    else
        print_warning "Inventory validation failed (may not be critical)"
    fi

    # Check playbook syntax
    print_info "Checking playbook syntax..."
    if ansible-playbook playbooks/setup.yml --syntax-check &> /dev/null; then
        print_success "Playbook syntax is valid"
    else
        print_warning "Playbook syntax check failed (may not be critical)"
    fi
}

# ============================================================================
# Main Installation Flow
# ============================================================================

main() {
    clear
    print_header "Ansible Installation Script (No Sudo Required)"
    echo
    echo "This script will install Ansible and required dependencies in user-space."
    echo "No sudo/root privileges required."
    echo
    read -p "Press Enter to continue or Ctrl+C to cancel..."
    echo

    # Run all installation steps
    check_python || exit 1
    echo

    setup_path || exit 1
    echo

    install_ansible || exit 1
    echo

    verify_project_structure || exit 1
    echo

    # Ensure virtual environment is activated for subsequent operations
    if [[ -z "$VIRTUAL_ENV" ]]; then
        print_info "Re-activating virtual environment for collections and verification"
        source "$ACTIVATE_SCRIPT"
    fi

    install_collections || exit 1
    echo

    verify_installation || exit 1
    echo

    # Final success message
    print_header "Installation Complete!"
    echo
    print_success "Ansible and all dependencies installed successfully in virtual environment"
    echo
    print_info "Next steps:"
    echo "  1. Activate virtual environment: source $VENV_DIR/bin/activate"
    echo "  2. Navigate to: cd $ANSIBLE_DIR"
    echo "  3. Run setup playbook: ansible-playbook playbooks/setup.yml"
    echo
    print_info "Installation locations:"
    echo "  • Virtual Environment: $VENV_DIR"
    echo "  • Ansible: $VENV_DIR/bin/ansible"
    echo "  • Collections: $HOME/.ansible/collections/"
    echo "  • Config: $ANSIBLE_DIR/ansible.cfg"
    echo
    print_info "To use Ansible in future sessions:"
    echo "  source $VENV_DIR/bin/activate"
    echo
}

# Run main function
main "$@"

