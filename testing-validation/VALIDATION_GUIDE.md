# Validation Script Usage

This project includes a comprehensive validation script that checks Terraform, Ansible, documentation, security, and code quality.

## Quick Start

```bash
# Validate everything
./env-validate.sh

# Skip specific components
./env-validate.sh --skip-ansible
./env-validate.sh --skip-terraform

# Use custom directories
./env-validate.sh --terraform-dir infra --ansible-dir automation

# Get help
./env-validate.sh --help
```

## What It Checks

### Terraform Validation

- ✅ Syntax validation (`terraform validate`)
- ✅ Code formatting (`terraform fmt`)
- ✅ Required files (main.tf, variables.tf, outputs.tf)
- ✅ Variable usage analysis (detects unused variables)
- ✅ Hardcoded values detection
- ✅ Configuration dry-run testing

### Ansible Validation

- ✅ Ansible lint checks
- ✅ YAML syntax validation
- ✅ Project structure verification
- ✅ Vault file detection

### Security Validation

- ✅ Sensitive file detection (keys, certificates, state files)
- ✅ .gitignore presence
- ✅ Hardcoded secrets scanning

### Documentation Validation

- ✅ README.md presence and content
- ✅ Architecture documentation
- ✅ Migration guides

### Code Quality

- ✅ TODO/FIXME comment detection
- ✅ Trailing whitespace
- ✅ Line ending consistency

### Performance and Database Validation

- ✅ AWR analysis queries validation
- ✅ Performance benchmark testing
- ✅ Infrastructure health checks
- ✅ Database connection validation
- ✅ Oracle 19c partition support testing

## Exit Codes

- `0` - All validations passed
- `1` - Critical validation failures found

## Example Output

```bash
🚀 INFRASTRUCTURE VALIDATION STARTED
===================================
ℹ Project: my-project
ℹ Timestamp: Mon Oct 07 12:00:00 EDT 2025

TERRAFORM VALIDATION
====================
✅ Terraform syntax validation
✅ Terraform formatting check
✅ All declared variables are used

📊 VALIDATION SUMMARY
====================
Total Checks: 15
Passed: 13
Failed: 0
Warnings: 2

🎉 ALL VALIDATIONS PASSED!
```

## Customization

The script is designed to be generic and reusable across different projects. You can:

1. **Modify validation rules** by editing the validation functions
2. **Add new checks** by extending the validation modules
3. **Customize patterns** for security and quality scanning
4. **Configure directories** via command line arguments

## Integration

### CI/CD Integration

```yaml
# GitHub Actions example
- name: Validate Infrastructure
  run: ./env-validate.sh
```

### Pre-commit Hook

```bash
#!/bin/sh
./env-validate.sh --skip-ansible
```

This validation script helps maintain code quality, security, and consistency across infrastructure projects.
