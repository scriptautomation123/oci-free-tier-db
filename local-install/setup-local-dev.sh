#!/bin/bash
# ==============================================================================
# Local Development Environment Setup - Main Installer
# ==============================================================================
# This script sets up everything needed for local development:
# - Ansible virtual environment and collections
# - Environment validation tools
# - Terraform configuration helpers
# - Quality assurance tools
# ==============================================================================

set -e

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

print_header() {
    echo -e "${BOLD}${BLUE}=============================================================================="
    echo -e "$1"
    echo -e "==============================================================================${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

check_prerequisites() {
    print_header "🔍 Checking Prerequisites"
    
    # Check Python
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 is required but not installed"
        print_info "Please install Python 3.6+ and re-run this script"
        exit 1
    fi
    
    local python_version
    python_version=$(python3 --version 2>&1 | awk '{print $2}')
    print_success "Python $python_version found"
    
    # Check Git
    if ! command -v git &> /dev/null; then
        print_error "Git is required but not installed"
        exit 1
    fi
    print_success "Git found"
    
    # Check if we're in the right directory
    if [[ ! -f "$PROJECT_ROOT/README.md" ]] || [[ ! -d "$PROJECT_ROOT/terraform" ]]; then
        print_error "This doesn't appear to be the project root directory"
        print_info "Expected to find README.md and terraform/ directory"
        exit 1
    fi
    print_success "Project structure validated"
}

install_ansible_environment() {
    print_header "🔧 Installing Ansible Environment"
    
    cd "$SCRIPT_DIR"
    
    if [[ -f "install-ansible.sh" ]]; then
        print_info "Running Ansible installation script..."
        bash install-ansible.sh
        print_success "Ansible environment installed"
    else
        print_error "install-ansible.sh not found in $SCRIPT_DIR"
        exit 1
    fi
}

setup_terraform_tools() {
    print_header "🏗️  Setting up Terraform Tools"
    
    if [[ -f "$SCRIPT_DIR/setup-env-vars.sh" ]]; then
        print_success "Terraform environment setup script available"
        print_info "Run './setup-env-vars.sh' when ready to configure Terraform"
    else
        print_warning "setup-env-vars.sh not found"
    fi
    
    if [[ -f "$SCRIPT_DIR/generate-tfvars.sh" ]]; then
        print_success "Terraform tfvars generator available"
    else
        print_warning "generate-tfvars.sh not found"
    fi
}

install_quality_tools() {
    print_header "🔍 Setting up Quality Assurance Tools"
    
    # Check if trunk is available
    if command -v trunk &> /dev/null; then
        print_success "Trunk found - code quality tools available"
        cd "$PROJECT_ROOT"
        trunk install 2>/dev/null || true
    else
        print_info "Trunk not found - install with: curl https://get.trunk.io -fsSL | bash"
    fi
    
    if [[ -f "$SCRIPT_DIR/env-validate.sh" ]]; then
        print_success "Environment validation script available"
    else
        print_warning "env-validate.sh not found"
    fi
}

create_convenience_scripts() {
    print_header "🚀 Creating Convenience Scripts"
    
    # Create a quick activation script in project root
    cat > "$PROJECT_ROOT/dev-env.sh" << 'EOF'
#!/bin/bash
# Quick development environment activation
# Usage: source ./dev-env.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🚀 Activating development environment..."

# Activate Ansible virtual environment
if [[ -f "$SCRIPT_DIR/.venv/bin/activate" ]]; then
    source "$SCRIPT_DIR/.venv/bin/activate"
    echo "✅ Ansible virtual environment activated"
else
    echo "⚠️  Virtual environment not found. Run local-install/setup-local-dev.sh first"
fi

# Set up Ansible configuration
export ANSIBLE_CONFIG="$SCRIPT_DIR/.ansible/ansible.cfg"
export ANSIBLE_DEPRECATION_WARNINGS=False

# Add helpful aliases
alias ansible-validate="cd '$SCRIPT_DIR' && ansible-playbook ansible/playbooks/setup.yml --check"
alias terraform-plan="cd '$SCRIPT_DIR/terraform' && terraform plan"
alias validate-env="'$SCRIPT_DIR/local-install/env-validate.sh'"

echo "✅ Development environment ready!"
echo ""
echo "Available commands:"
echo "  ansible-validate  - Validate Ansible setup"
echo "  terraform-plan    - Plan Terraform deployment"
echo "  validate-env      - Run full environment validation"
echo ""
echo "Ansible config: $ANSIBLE_CONFIG"
echo "To deactivate: deactivate"
EOF

    chmod +x "$PROJECT_ROOT/dev-env.sh"
    print_success "Created dev-env.sh in project root for quick activation"
}

show_next_steps() {
    print_header "🎉 Installation Complete!"
    
    echo -e "${GREEN}Your local development environment is ready!${NC}"
    echo ""
    echo -e "${BOLD}📋 Next Steps:${NC}"
    echo ""
    echo -e "${YELLOW}1. Quick Start (Recommended):${NC}"
    echo "   source ./dev-env.sh"
    echo ""
    echo -e "${YELLOW}2. Manual Activation:${NC}"
    echo "   cd local-install"
    echo "   ./activate-ansible.sh"
    echo ""
    echo -e "${YELLOW}3. Configure Terraform:${NC}"
    echo "   cd local-install"
    echo "   ./setup-env-vars.sh"
    echo ""
    echo -e "${YELLOW}4. Validate Everything:${NC}"
    echo "   cd local-install"
    echo "   ./env-validate.sh"
    echo ""
    echo -e "${BOLD}📁 Available Tools:${NC}"
    echo "   • Ansible virtual environment (.venv/)"
    echo "   • Role-based playbooks (ansible/playbooks/)"
    echo "   • Environment validation (local-install/env-validate.sh)"
    echo "   • Terraform helpers (local-install/setup-env-vars.sh)"
    echo "   • Quick activation (./dev-env.sh)"
    echo ""
    echo -e "${BLUE}💡 Tip: Run 'source ./dev-env.sh' for the fastest setup!${NC}"
}

main() {
    clear
    print_header "🚀 Local Development Environment Setup"
    echo ""
    echo "This script will set up everything needed for local development:"
    echo "• Ansible virtual environment and collections"
    echo "• Terraform configuration tools"
    echo "• Environment validation scripts"
    echo "• Quality assurance tools"
    echo ""
    read -p "Press Enter to continue or Ctrl+C to cancel..."
    echo ""
    
    check_prerequisites
    install_ansible_environment
    setup_terraform_tools
    install_quality_tools
    create_convenience_scripts
    show_next_steps
}

# Only run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi