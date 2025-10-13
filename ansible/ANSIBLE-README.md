# Oracle Cloud Automation - Ansible Orchestration

🚀 **Master orchestrator for Oracle Cloud Infrastructure automation**

This Ansible configuration provides comprehensive orchestration for Oracle Cloud deployment, including infrastructure provisioning via Terraform integration.

## 📋 When to Use Ansible vs GitHub Actions

This project supports **two complementary approaches** for infrastructure provisioning:

| Approach | Best For | Terraform Execution |
|----------|----------|---------------------|
| **GitHub Actions** | CI/CD pipelines, team collaboration, production deployments | ✅ Direct (industry standard) |
| **Ansible (this directory)** | Local development, interactive workflows, custom orchestration | Via Ansible wrapper |

📖 **See**: [`../.github/GITHUB_ACTIONS_GUIDE.md`](../.github/GITHUB_ACTIONS_GUIDE.md) for detailed comparison and when to use each approach.

## 🚨 ALWAYS FREE TIER PROTECTION 🚨

This Ansible-based automation provides **zero-cost** Oracle Cloud deployment with **no sudo privileges required**.

## Key Benefits over Bash Scripts

✅ **No Sudo Required** - All tools installed to user space
✅ **Idempotent Operations** - Safe to run multiple times
✅ **Better Error Handling** - Comprehensive validation and rollback
✅ **Structured Configuration** - YAML-based, version-controlled
✅ **Cross-Platform** - Works on Linux and macOS
✅ **Modular Design** - Individual playbooks for each phase
✅ **Always Free Protection** - Built-in cost validation

## Quick Start

### 1. Install Ansible (one-time setup)

```bash
# Using pip (no sudo required)
pip install --user ansible

# Or using package manager (if you have sudo)
# Ubuntu/Debian: sudo apt install ansible
# macOS: brew install ansible
```

### 2. Run Complete Deployment

```bash
cd ansible

# Complete end-to-end deployment (RECOMMENDED)
ansible-playbook playbooks/deploy-complete-suite.yml

# OR run individual steps manually
ansible-playbook playbooks/setup-environment.yml
ansible-playbook playbooks/deploy-database.yml
# Package installation is included in deploy-complete-suite.yml
```

### 3. Connect to Your Database

```bash
# Use generated convenience script
../connect-db.sh

# Or connect manually
sqlplus ADMIN/[password]@[database]_HIGH

# Connection details are saved to logs/connection-details.txt
```

## Individual Playbooks

### Setup Environment (replaces setup-oci-cli.sh)

```bash
ansible-playbook playbooks/setup-environment.yml
```

- Installs Terraform to `~/.local/bin/` (no sudo)
- Installs OCI CLI via `pip --user` (no sudo)
- Updates shell PATH configuration
- Validates Always Free tier settings

### Deploy Database (replaces create-test-database.sh)

```bash
ansible-playbook playbooks/deploy-database.yml
```

- Creates Always Free Oracle Autonomous Database
- Validates free tier limits and existing usage
- Generates wallet and connection details
- Zero cost guarantee with validation

### Deploy Complete Suite (RECOMMENDED)

```bash
ansible-playbook playbooks/deploy-complete-suite.yml
```

- Orchestrates the complete deployment workflow
- Includes environment setup, database creation, package installation, and validation
- Provides end-to-end automation with proper sequencing
- Handles error conditions and rollback scenarios

### Cleanup Resources (replaces cleanup-resources.sh)

```bash
ansible-playbook playbooks/cleanup-resources.yml
```

- Safe resource destruction with confirmations
- Automatic backup of important files
- Optional data export before cleanup
- Verification of complete cleanup

### Additional Specialized Playbooks

```bash
# Infrastructure provisioning only
ansible-playbook playbooks/provision-infrastructure-only.yml

# Testing and validation only
ansible-playbook playbooks/test-and-validate-only.yml
```

These specialized playbooks allow for targeted operations without running the complete deployment suite.

## Configuration

Edit `inventory/localhost.yml` to customize:

```yaml
vars:
  # Tool versions
  terraform_version: "1.6.6"
  oci_cli_version: "latest"

  # Always Free protection
  always_free_tier: true
  max_cpu_cores: 1
  max_storage_gb: 20
```

## User-Space Tool Installation

### Terraform

- Downloaded as pre-compiled binary
- Installed to `~/.local/bin/terraform`
- No package manager or sudo required

### OCI CLI

- Installed via `pip install --user oci-cli`
- Binaries in `~/.local/bin/oci`
- Python dependencies in `~/.local/lib/`

### PATH Updates

- Automatically adds `~/.local/bin` to shell PATH
- Works with both bash and zsh
- Persistent across sessions

## Always Free Tier Protection

All playbooks include comprehensive validation:

- ✅ CPU cores limited to 1
- ✅ Storage limited to 20GB
- ✅ Auto-scaling disabled
- ✅ Free tier flag enforced
- ✅ Existing database quota checking
- ✅ Cost estimation and validation

## Error Handling

Ansible provides superior error handling:

- **Validation** - Pre-flight checks before operations
- **Rollback** - Automatic cleanup on failures
- **Idempotency** - Safe to re-run after failures
- **Detailed Logging** - Comprehensive execution logs
- **State Management** - Tracks what's been completed

## File Structure

```bash
ansible/
├── playbooks/
│   ├── deploy-complete-suite.yml  # Master orchestration (RECOMMENDED)
│   ├── setup-environment.yml      # Environment setup
│   ├── deploy-database.yml        # Database creation
│   ├── cleanup-resources.yml      # Resource cleanup
│   ├── provision-infrastructure-only.yml  # Infrastructure only
│   ├── test-and-validate-only.yml # Testing only
│   └── tasks/                     # Task modules
│       ├── provision-infrastructure.yml
│       ├── configure-database.yml
│       ├── deploy-packages.yml    # Package installation
│       └── test-and-validate.yml
├── inventory/
│   └── localhost.yml              # Local inventory configuration
├── templates/                     # Configuration templates
└── ansible.cfg                    # Ansible configuration
```

## Comparison: Bash vs Ansible

| Feature           | Bash Scripts  | Ansible Playbooks |
| ----------------- | ------------- | ----------------- |
| Sudo Requirements | ✅ Required   | ❌ None           |
| Error Handling    | Basic         | Comprehensive     |
| Idempotency       | Manual        | Built-in          |
| Configuration     | Hardcoded     | YAML-based        |
| Validation        | Limited       | Extensive         |
| Rollback          | Manual        | Automatic         |
| Cross-Platform    | Linux-focused | Linux + macOS     |
| State Management  | None          | Built-in          |
| Logging           | Basic         | Structured        |
| Modularity        | Limited       | High              |

## Migration from Bash Scripts

The Ansible playbooks are **functionally equivalent** to the bash scripts but with significant improvements:

1. **setup-oci-cli.sh** → `setup-environment.yml`
2. **create-test-database.sh** → `deploy-database.yml`
3. **deploy-complete-suite.sh** → `deploy-complete-suite.yml` (orchestrated approach)
4. **cleanup-resources.sh** → `cleanup-resources.yml`

**Note**: Package installation is now handled as part of the `deploy-complete-suite.yml` orchestration for better integration and error handling.

## Always Free Tier Benefits

- **Cost**: $0.00 - No charges ever
- **Time Limits**: None - Resources never expire
- **Database**: 1 OCPU, 20GB storage per database
- **Limit**: Up to 2 databases per tenancy
- **Storage**: 20GB Object Storage per region
- **Networking**: VCN and basic networking included

## Support

For issues:

1. Check execution logs in `../logs/`
2. Verify configuration in `inventory/localhost.yml`
3. Ensure OCI CLI is configured: `oci setup config`
4. Validate Terraform state: `terraform state list`
5. Run validation script: `../testing-validation/env-validate.sh`

The Ansible approach provides enterprise-grade automation while maintaining the zero-cost Always Free tier guarantee.
