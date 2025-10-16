# Oracle Cloud Infrastructure Free Tier Database Suite - AI Coding Agent Instructions

## Architecture Overview

This is a **hybrid orchestration architecture** that combines Terraform (infrastructure) with Ansible (application deployment) for Oracle Cloud Always Free tier database automation. The separation is intentional and critical:

- **Terraform** (`terraform/`): Pure infrastructure provisioning, state management, Always Free tier protection
- **Ansible** (`ansible/`): Orchestration, configuration, package deployment, testing, and validation
- **Master Orchestrator**: `ansible/playbooks/deploy-complete-suite.yml` coordinates everything

## Critical Cost Protection Rules

**NEVER MODIFY THESE VALUES** - they prevent charges:

```hcl
# terraform/main.tf - Always Free enforcement
cpu_core_count = 1                    # Exactly 1, never more
data_storage_size_in_gb = 20          # 20GB max (0.02 TB)
is_free_tier = true                   # Must be true
is_auto_scaling_enabled = false       # Must be false
license_model = "LICENSE_INCLUDED"    # Always Free requirement

lifecycle {
  prevent_destroy = true              # Critical protection
  ignore_changes = [                  # Prevent drift charges
    cpu_core_count,
    data_storage_size_in_gb,
    is_auto_scaling_enabled,
    is_free_tier
  ]
}
```

## Key Development Workflows

### Complete Deployment

```bash
# Single command deployment (most common)
ansible-playbook ansible/playbooks/deploy-complete-suite.yml

# Infrastructure only
ansible-playbook ansible/playbooks/provision-infrastructure-only.yml

# Testing only (requires existing infrastructure)
ansible-playbook ansible/playbooks/test-and-validate-only.yml --tags testing
```

### Validation & Quality Assurance

```bash
# Comprehensive validation (run before commits)
./env-validate.sh

# Auto-fix Ansible issues
./env-validate.sh --fix

# Terraform-specific validation
cd terraform && terraform validate && terraform fmt -check
```

### Safe Cleanup

```bash
# Always use the playbook for cleanup (never manual terraform destroy)
ansible-playbook ansible/playbooks/cleanup-resources.yml
```

## Project-Specific Patterns

### 1. No Sudo Requirements

All tools install to `~/.local/bin/` - never use sudo or system-wide installations:

```bash
# Pattern used throughout
pip3 install --user ansible oci-cli
wget terraform.zip && unzip -d ~/.local/bin/
```

### 2. Dual-Layer Validation

Always validate at both infrastructure and application layers:

```yaml
# Ansible validation after Terraform
- name: Verify Always Free compliance
  assert:
    that:
      - infrastructure.database_config.value.cpu_core_count == 1
      - infrastructure.database_config.value.is_free_tier == true
```

### 3. Error Recovery Pattern

Use block/rescue for all destructive operations:

```yaml
- name: Dangerous operation
  block:
    - name: Backup before change
      copy: src=config.tf dest=config.tf.backup
    - name: Make change
      # ... operation
  rescue:
    - name: Restore on failure
      copy: src=config.tf.backup dest=config.tf
```

### 4. Template-Driven Configuration

Connection details, scripts, and reports use Jinja2 templates in `ansible/templates/`:

```yaml
- name: Generate connection info
  template:
    src: connection-details.txt.j2
    dest: "{{ project_root }}/connection-details.txt"
```

## Integration Points

### Terraform → Ansible Data Flow

Ansible calls Terraform and consumes outputs:

```bash
# In provision-infrastructure.yml
terraform apply -var-file="terraform.tfvars"
terraform output -json > outputs.json
```

### Always Free Tier Protection

Multiple validation layers prevent charges:

1. **Variable validation** in `terraform/variables.tf`
2. **Lifecycle rules** in `terraform/main.tf`
3. **Runtime assertions** in Ansible playbooks
4. **User confirmations** before destructive operations

### Wallet-Based Authentication

Oracle Autonomous Database uses wallet files (never passwords in connection strings):

```yaml
- name: Configure wallet
  file:
    path: "{{ wallet_dir }}"
    mode: "0700" # Owner-only access
- name: Set TNS_ADMIN
  shell: export TNS_ADMIN="{{ wallet_dir }}"
```

## File Structure Conventions

### Terraform Organization

```
terraform/
├── main.tf          # Resources with lifecycle protection
├── variables.tf     # Comprehensive validation rules
├── outputs.tf       # Infrastructure data for Ansible
└── terraform.tfvars # Environment-specific values
```

### Ansible Organization

```
ansible/
├── playbooks/
│   ├── deploy-complete-suite.yml    # 🎯 Main entry point
│   ├── tasks/                       # Modular task files
│   │   ├── provision-infrastructure.yml  # Terraform integration
│   │   ├── configure-database.yml       # Database setup
│   │   └── test-and-validate.yml        # Testing framework
│   └── cleanup-resources.yml        # Safe resource removal
└── templates/                       # Jinja2 templates for config
```

## Common Debugging Patterns

### Infrastructure Issues

```bash
cd terraform
terraform plan -var-file=terraform.tfvars  # Check plan
terraform show terraform.tfstate           # Inspect state
```

### Ansible Issues

```bash
cd ansible
ansible-lint --offline playbooks/         # Lint all playbooks
ansible-playbook playbooks/deploy-complete-suite.yml --check --diff
```

### Always Free Tier Verification

```bash
# Check current quota usage
oci limits resource-availability get --compartment-id [ID] --limit-name database
```

## Security Considerations

- **Credentials**: Auto-generated, stored in Terraform state (encrypted)
- **Wallet files**: Strict 0700 permissions, never committed
- **Network**: Configurable IP whitelisting via `whitelisted_ips` variable
- **State files**: Never commit `.tfstate` files

## Testing Approach

- **Infrastructure**: Terraform plan validation
- **Application**: Ansible dry-run with `--check`
- **Integration**: End-to-end validation via `test-and-validate.yml`
- **Compliance**: Always Free tier verification at multiple layers

## External Dependencies

- **Oracle Cloud account** with Always Free tier eligibility
- **OCI CLI** for authentication and API access
- **Terraform ~> 1.0** for infrastructure provisioning
- **Ansible** for orchestration and deployment
- **Python 3** for OCI SDK and Ansible execution

## Documentation and Summary Files

**IMPORTANT**: Before creating any summary, refactor, changelog, or documentation file about actions taken:

1. **Ask the user first** if they want a summary document created
2. **Explain what will be included** in the summary (e.g., changes made, metrics, comparisons)
3. **Wait for user confirmation** before creating the file

**Examples of files that require user approval:**
- `REFACTOR-SUMMARY.md`
- `IMPLEMENTATION-SUMMARY.md`
- `MIGRATION-GUIDE.md`
- `CHANGELOG.md`
- `*-COMPARISON.md`
- `*-VISUAL.txt`

**Exception**: Brief inline summaries in conversation responses are fine. This rule applies only to creating separate summary documents/files.

Remember: This architecture prioritizes **zero cost** operation above all else. Every change must preserve Always Free tier compliance.
