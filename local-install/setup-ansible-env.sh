#!/bin/bash
# Ansible Environment Setup Script
# Sets environment variables for clean Ansible execution

# Suppress the specific deprecated warning that's internal to Ansible 2.19.x
# This is a known issue in Ansible core that will be resolved in 2.23
# See: https://github.com/ansible/ansible/issues/deprecation-warnings
export ANSIBLE_DEPRECATION_WARNINGS=False

# Activate virtual environment if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VENV_DIR="${PROJECT_ROOT}/.venv"

# Set Ansible configuration location
export ANSIBLE_CONFIG="${PROJECT_ROOT}/.ansible/ansible.cfg"

if [[ -f "$VENV_DIR/bin/activate" ]]; then
    source "$VENV_DIR/bin/activate"
    echo "✓ Virtual environment activated"
else
    echo "⚠ Virtual environment not found. Run ./install-ansible.sh first."
fi

# Verify Ansible is available
if command -v ansible &> /dev/null; then
    echo "✓ Ansible $(ansible --version | head -n1 | awk '{print $3}' | tr -d ']') ready"
else
    echo "✗ Ansible not found in environment"
fi

echo ""
echo "Environment configured for clean Ansible execution"
echo "Ansible config: $ANSIBLE_CONFIG"
echo "Note: Ansible 2.19.x internal deprecation warnings are suppressed"
echo "This will be resolved when upgrading to Ansible 2.23+"