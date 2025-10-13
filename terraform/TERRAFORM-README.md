# Oracle Cloud Infrastructure Automation

This directory contains Terraform configurations for automatically provisioning Oracle Cloud infrastructure to test the partition management suite.

## 🚨 ALWAYS FREE TIER PROTECTION 🚨

This configuration is specifically designed to use **Oracle Always Free tier resources** to prevent any charges. The system includes multiple safety measures:

### Built-in Cost Protection

- ✅ CPU validation: Enforces exactly 1 OCPU (free tier limit)
- ✅ Storage validation: Enforces maximum 20GB (0.02TB) storage
- ✅ Auto-scaling disabled: Prevents automatic cost increases
- ✅ Lifecycle protection: `prevent_destroy` on database to avoid accidental deletion
- ✅ Cost monitoring tags: All resources tagged for cost tracking

### Always Free Tier Limits

Oracle Cloud Always Free tier provides:

- **1 Oracle Autonomous Database** (1 OCPU, 20GB storage)
- **20GB Object Storage**
- **No time limits** on these resources

## Prerequisites

1. **Oracle Cloud Account** with Always Free tier
2. **OCI CLI** configured with your credentials
3. **Terraform** (version 0.12 or later)

## Quick Start

### Option 1: GitHub Actions (Recommended for Teams)

For automated infrastructure provisioning via CI/CD:

```bash
# See the comprehensive guide:
../.github/GITHUB_ACTIONS_GUIDE.md

# Quick steps:
# 1. Configure GitHub Secrets in repository settings
# 2. Navigate to Actions tab
# 3. Select "Provision OCI Infrastructure" workflow
# 4. Click "Run workflow" → Select "apply"
# 5. Approve deployment in environment gate
```

**Why this approach?**
- ✅ Industry best practice for Terraform in CI/CD
- ✅ Built-in approval gates and audit trails
- ✅ Team collaboration via PR reviews
- ✅ Direct Terraform execution (no wrapper overhead)

### Option 2: Local Development with Ansible

For interactive local development:

```bash
# Ansible orchestrates Terraform with additional validation
cd ../ansible
ansible-playbook playbooks/deploy-database.yml
```

### Option 3: Direct Terraform (Development/Debugging Only)

1. **Navigate to the terraform directory**:

   ```bash
   cd terraform
   ```

2. **Configure your environment**:

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your OCI details
   ```

3. **Initialize and deploy**:
   ```bash
   terraform init
   terraform plan    # Review the planned changes
   terraform apply   # Deploy resources
   ```

## Configuration

### Required Variables

Edit `terraform.tfvars` with your OCI details:

```hcl
# Your OCI compartment OCID
compartment_ocid = "ocid1.compartment.oc1..aaaaaaaa..."

# OCI region
region = "us-ashburn-1"

# Acknowledge free tier limits (required)
acknowledge_free_tier_limits = true
```

### Always Free Tier Settings (Pre-configured)

These settings are optimized for Always Free tier and should not be changed:

```hcl
cpu_core_count = 1                # Exactly 1 OCPU (free tier limit)
storage_size_tbs = 0.02          # 20GB storage (free tier limit)
auto_scaling_enabled = false     # Must be disabled for free tier
is_free_tier = true              # Uses Always Free tier
license_model = "LICENSE_INCLUDED"
```

## Validation Rules

The Terraform configuration includes validation to prevent accidental charges:

- **CPU Validation**: Ensures exactly 1 OCPU when using free tier
- **Storage Validation**: Prevents exceeding 20GB storage limit
- **Free Tier Acknowledgment**: Requires explicit confirmation of free tier limits

## Resources Created

- **Oracle Autonomous Database**: 1 OCPU, 20GB storage, Always Free tier
- **Object Storage Bucket**: For data loading and backups (20GB limit)
- **All necessary networking**: VCN, subnets, security lists

## Important Notes

⚠️ **Cost Safety**: This configuration is designed to stay within Always Free tier limits. Modifying the validated parameters may result in charges.

⚠️ **Resource Limits**: Always Free tier has a limit of 2 Autonomous Databases per tenancy. If you already have 2, you'll need to terminate one first.

⚠️ **Region Availability**: Always Free resources are available in home region and one additional region. Verify your region supports Always Free tier.

## Integration with Ansible

🤖 **This Terraform configuration is designed to be orchestrated by Ansible.**

**DO NOT run Terraform commands directly in production environments.**

Instead, use the provided Ansible playbooks:

```bash
# Full deployment orchestration
ansible-playbook ../ansible/playbooks/deploy-complete-suite.yml

# Infrastructure only
ansible-playbook ../ansible/playbooks/deploy-database.yml

# Safe cleanup
ansible-playbook ../ansible/playbooks/cleanup-resources.yml
```

### Why Ansible Orchestration?

- **Cost Protection**: Multi-layer validation prevents accidental charges
- **User Experience**: Progress indicators and comprehensive error handling
- **Environment Setup**: Automatic tool installation and configuration
- **Application Integration**: Seamless database configuration and package deployment
- **Safety Features**: Pre-flight checks and Always Free tier validation

### Manual Terraform Usage (Development Only)

If you need to run Terraform directly for development/debugging:

```bash
# Initialize and validate
terraform init
terraform validate

# Plan with Always Free protection
terraform plan -var-file="terraform.tfvars"

# Apply (only after thorough review)
terraform apply

# Always check outputs
terraform output
```

**⚠️ WARNING**: Direct Terraform usage bypasses Ansible's cost protection and validation layers.

## Outputs

After successful deployment, you'll receive:

- Database connection strings
- Admin username and password
- Object storage bucket details
- SQL\*Plus connection examples

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

Note: The database has `prevent_destroy` enabled. You'll need to remove this protection if you want to destroy it via Terraform.
