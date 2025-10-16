# Local Development Installation Scripts

This folder contains all the scripts and tools needed for local development setup.

## 📋 **Quick Start**

```bash
# 1. Install all development tools
./setup-local-dev.sh

# 2. Activate Ansible environment
./activate-ansible.sh

# 3. Validate environment
./env-validate.sh
```

## 🛠️ **Available Scripts**

### **Core Installation**
- `setup-local-dev.sh` - **Main installer** (installs everything)
- `install-ansible.sh` - Install Ansible in virtual environment
- `activate-ansible.sh` - Activate Ansible virtual environment
- `setup-ansible-env.sh` - Configure Ansible environment variables

### **Terraform Tools**
- `setup-env-vars.sh` - Interactive Terraform variable setup
- `generate-tfvars.sh` - Generate terraform.tfvars from environment

### **Validation & Quality**
- `env-validate.sh` - Comprehensive environment validation
- `.env.template` - GitHub Actions environment variables template

## 🎯 **Usage Patterns**

### **First Time Setup**
```bash
cd local-install
./setup-local-dev.sh
```

### **Daily Development**
```bash
cd local-install
./activate-ansible.sh  # Opens new shell with Ansible activated
# Work in activated environment
exit  # Return to normal shell
```

### **Environment Validation**
```bash
cd local-install
./env-validate.sh --fix  # Validate and auto-fix issues
```

### **Terraform Configuration**
```bash
cd local-install
./setup-env-vars.sh      # Interactive setup
./generate-tfvars.sh     # Generate terraform.tfvars
```

## 📁 **File Organization**

```
local-install/
├── README.md                    # This file
├── setup-local-dev.sh           # Main installer
├── install-ansible.sh           # Ansible installation
├── activate-ansible.sh          # Ansible activation
├── setup-ansible-env.sh         # Ansible environment
├── setup-env-vars.sh           # Terraform variables setup
├── generate-tfvars.sh          # Terraform variables generator
├── env-validate.sh             # Environment validation
└── .env.template               # GitHub Actions template
```

## 🔧 **Integration with Main Project**

These scripts work with the main project structure:
- **Ansible**: `../ansible/` (role-based structure)
- **Terraform**: `../terraform/` (infrastructure)
- **Virtual Environment**: `../.venv/` (Python/Ansible)
- **Configuration**: `../.ansible/` (centralized config)

## 💡 **Tips**

- Run `setup-local-dev.sh` once for initial setup
- Use `activate-ansible.sh` when working with Ansible
- Run `env-validate.sh` before committing changes
- Use `setup-env-vars.sh` for Terraform configuration
- All scripts work from any directory location