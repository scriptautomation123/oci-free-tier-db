# Quick Usage Guide

## New Role-Based Architecture

This project now uses a clean **Ansible role architecture** that eliminates duplication and provides simple, focused playbooks.

## Prerequisites Setup

**First-time environment setup (installs Terraform & OCI CLI):**

```bash
cd /home/swapa/code/oci-free-tier-db
source .venv/bin/activate
ANSIBLE_CONFIG=.ansible/ansible.cfg ansible-playbook ansible/playbooks/setup.yml
```

## Main Deployment Options

### Complete Deployment (Recommended)

```bash
cd /home/swapa/code/oci-free-tier-db
source .venv/bin/activate
ANSIBLE_CONFIG=.ansible/ansible.cfg ansible-playbook ansible/playbooks/site.yml
```

### Focused Deployments

```bash
# Environment setup only
ansible-playbook ansible/playbooks/setup.yml

# Full deployment with test data
ansible-playbook ansible/playbooks/deploy.yml

# Testing and validation only
ansible-playbook ansible/playbooks/test.yml

# Resource cleanup
ansible-playbook ansible/playbooks/cleanup.yml
```

## Advanced Usage

### Tag-Based Execution

```bash
# Run specific phases using tags
ansible-playbook ansible/playbooks/site.yml --tags setup
ansible-playbook ansible/playbooks/site.yml --tags infrastructure,database
ansible-playbook ansible/playbooks/site.yml --tags testing
```

### Variable Overrides

```bash
# Custom deployment action
ansible-playbook ansible/playbooks/deploy.yml -e "oracle_deployment_action=reset-schema"

# Enable test data loading
ansible-playbook ansible/playbooks/deploy.yml -e "oracle_load_test_data=true"

# Set environment
ansible-playbook ansible/playbooks/deploy.yml -e "oracle_deployment_environment=production"
```

## Role Architecture Benefits

### Clean Structure
```
ansible/
├── roles/oracle_cloud_automation/    # Single source of truth
│   ├── tasks/                        # All automation logic
│   ├── templates/                    # Configuration templates
│   ├── defaults/                     # Default variables
│   └── meta/                         # Role metadata
└── playbooks/                        # Simple orchestrators
    ├── site.yml                      # Complete deployment
    ├── setup.yml                     # Environment setup
    ├── deploy.yml                    # Full deployment
    ├── test.yml                      # Testing only
    └── cleanup.yml                   # Resource cleanup
```

### Key Improvements
- ✅ **No Duplication**: Single role contains all logic
- ✅ **Reusable**: Role can be used in other projects
- ✅ **Maintainable**: Changes in one place
- ✅ **Standard**: Follows Ansible best practices
- ✅ **Flexible**: Tag-based execution for specific phases

## Configuration

- **Ansible config:** `.ansible/ansible.cfg`
- **Inventory:** `.ansible/inventory/localhost.yml` 
- **Role defaults:** `ansible/roles/oracle_cloud_automation/defaults/main.yml`
- **Virtual environment:** `.venv/` (recommended)
- **Always Free tier protection:** Enabled by default
- **No sudo privileges required:** All user-space installation

## Migration from Old Playbooks

If you were using the old playbook structure:

**Old → New Mapping:**
- `local-complete.yml` → `site.yml` or `deploy.yml`
- `setup-environment.yml` → `setup.yml`
- `loal-test-validate.yml` → `test.yml`
- `cleanup-resources.yml` → `cleanup.yml`

**Variable Changes:**
Old variables are now prefixed with `oracle_`:
- `deployment_action` → `oracle_deployment_action`
- `load_test_data` → `oracle_load_test_data`
- `deployment_environment` → `oracle_deployment_environment`