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

1. **Navigate to the terraform directory**:
   ```bash
   cd oci/terraform
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

## Outputs

After successful deployment, you'll receive:
- Database connection strings
- Admin username and password
- Object storage bucket details
- SQL*Plus connection examples

## Cleanup

To destroy all resources:
```bash
terraform destroy
```

Note: The database has `prevent_destroy` enabled. You'll need to remove this protection if you want to destroy it via Terraform.