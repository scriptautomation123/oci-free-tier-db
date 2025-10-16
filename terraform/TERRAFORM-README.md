# Oracle Cloud Infrastructure - Terraform Configuration

Terraform configurations for provisioning Oracle Cloud Always Free tier infrastructure using environment variables for secure, flexible deployment.

## 🚨 ALWAYS FREE TIER PROTECTION

This configuration enforces **Oracle Always Free tier** limits to prevent any charges:

### Built-in Cost Protection

- ✅ **CPU Enforcement**: Exactly 1 OCPU (hardcoded in `variables.tf`)
- ✅ **Storage Enforcement**: Maximum 20GB/0.02TB (hardcoded in `variables.tf`)
- ✅ **Auto-scaling Disabled**: Prevents automatic cost increases
- ✅ **Lifecycle Protection**: `prevent_destroy` on database resources
- ✅ **Variable Validation**: Runtime checks prevent dangerous changes
- ✅ **Free Tier Flag**: `is_free_tier = true` (cannot be overridden)

### Always Free Tier Limits

- **2 Autonomous Databases** (1 OCPU, 20GB storage each)
- **20GB Object Storage** (across all buckets)
- **10GB Archive Storage**
- **No time limits** (resources remain free indefinitely)

⚠️ **Region Requirements**: Available in home region + one Always Free-eligible region

---

## 🔧 Configuration: Environment Variables (TF*VAR*\*)

**This project uses environment variables instead of hardcoded `terraform.tfvars` values.**

### Why This Approach?

| Benefit                | Description                                          |
| ---------------------- | ---------------------------------------------------- |
| **Security**           | No secrets committed to version control              |
| **Flexibility**        | Different configs per environment (dev/staging/prod) |
| **CI/CD Ready**        | GitHub Actions uses secrets directly                 |
| **Cost Protection**    | Always Free limits hardcoded in `variables.tf`       |
| **Developer Friendly** | Interactive setup scripts provided                   |

### Architecture Flow

```
┌─────────────────────────┐
│  Environment Variables  │
│    (TF_VAR_*)          │
└───────────┬─────────────┘
            │
            ├─── Local Dev: setup-env-vars.sh
            └─── CI/CD: GitHub Secrets
                        ↓
            ┌───────────────────────┐
            │   Terraform Runtime   │
            │   - variables.tf      │
            │   - validation rules  │
            │   - cost protection   │
            └───────────┬───────────┘
                        ↓
            ┌───────────────────────┐
            │   OCI Resources       │
            │   (Always Free Tier)  │
            └───────────────────────┘
```

---

## 📋 Prerequisites

1. **Oracle Cloud Account** with Always Free tier eligibility
2. **Terraform** >= 1.0 (tested with 1.5.0)
3. **OCI CLI** configured (for local development only)
4. **Bash** shell (for helper scripts)

---

## 🚀 Quick Start

### Option 1: GitHub Actions (Recommended)

**For CI/CD deployments using GitHub Secrets.**

1. **Configure Secrets** (Repository Settings > Secrets and Variables > Actions)

   Required Secrets:

   ```
   OCI_COMPARTMENT_OCID  # Your OCI compartment OCID
   DB_ADMIN_PASSWORD     # Optional (auto-generated if not provided)
   ```

2. **Run Workflow**
   - Navigate to **Actions** tab
   - Select **"Provision OCI Infrastructure"**
   - Click **"Run workflow"**
   - Approve in **production** environment gate

3. **How It Works**
   - Workflow exports `TF_VAR_*` from secrets
   - Terraform reads variables directly from environment
   - No `terraform.tfvars` file generated in CI
   - Always Free tier validation runs automatically

### Option 2: Local Development (Interactive)

**For developers working locally with environment variables.**

#### Step 1: Setup Environment Variables (Interactive)

```bash
cd terraform
source ./setup-env-vars.sh  # Interactive prompts for all variables
```

**What this does:**

- Prompts for OCI compartment OCID (required)
- Prompts for optional settings (region, db_name, etc.)
- Exports `TF_VAR_*` environment variables
- Saves to `~/.bashrc` for persistence

#### Step 2: Deploy

```bash
terraform init
terraform plan    # Review changes
terraform apply   # Deploy resources
```

**Note:** Terraform reads `TF_VAR_*` directly from environment—no `terraform.tfvars` file needed.

#### Alternative: Manual Environment Variables

```bash
# Set required variable
export TF_VAR_compartment_ocid="ocid1.compartment.oc1..aaaaaaaa..."

# Optional: Override defaults
export TF_VAR_region="us-ashburn-1"
export TF_VAR_db_name="MYDB"
export TF_VAR_environment_name="dev"

# Deploy
cd terraform
terraform plan
terraform apply
```

#### Alternative: Generate terraform.tfvars (Optional)

If you prefer working with a `terraform.tfvars` file locally:

```bash
# After setting TF_VAR_* environment variables
cd terraform
./generate-tfvars.sh  # Creates terraform.tfvars from env vars
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

### Option 3: Ansible Orchestration

**For full-stack deployment with validation and package installation.**

```bash
# Complete deployment (infrastructure + database packages)
cd ../ansible
ansible-playbook playbooks/deploy-complete-suite.yml

# Infrastructure only
ansible-playbook playbooks/provision-infrastructure-only.yml

# Cleanup
ansible-playbook playbooks/cleanup-resources.yml
```

**Why use Ansible?**

- Multi-layer cost protection and validation
- Automatic tool installation (`terraform`, `oci-cli`)
- Database configuration and package deployment
- Progress indicators and error handling
- Pre-flight Always Free tier checks

---

## 🔑 Environment Variables Reference

### Required

| Variable                  | Description          | Example                          |
| ------------------------- | -------------------- | -------------------------------- |
| `TF_VAR_compartment_ocid` | OCI compartment OCID | `ocid1.compartment.oc1..aaaa...` |

### Optional (with defaults from `variables.tf`)

| Variable                       | Default          | Description                         |
| ------------------------------ | ---------------- | ----------------------------------- |
| `TF_VAR_region`                | `us-ashburn-1`   | OCI region                          |
| `TF_VAR_db_name`               | `PARTTEST`       | Database name (1-8 chars)           |
| `TF_VAR_db_version`            | `19c`            | Oracle DB version (19c/21c/23c)     |
| `TF_VAR_environment_name`      | `partition-test` | Environment tag                     |
| `TF_VAR_admin_password`        | _auto-generated_ | Admin password (12-30 chars)        |
| `TF_VAR_create_storage_bucket` | `true`           | Create Object Storage bucket        |
| `TF_VAR_load_test_data`        | `false`          | Load test data                      |
| `TF_VAR_run_validation_tests`  | `false`          | Run validation tests                |
| `TF_VAR_test_data_size`        | `small`          | Test data size (small/medium/large) |
| `TF_VAR_backup_retention_days` | `7`              | Backup retention (1-60 days)        |
| `TF_VAR_whitelisted_ips`       | `[]`             | IP whitelist (JSON array)           |

### Protected (Hardcoded in variables.tf)

These **cannot be overridden** to prevent charges:

```hcl
cpu_core_count        = 1                     # Exactly 1 OCPU
storage_size_tbs      = 0.02                  # 20GB max
auto_scaling_enabled  = false                 # Must be disabled
is_free_tier         = true                   # Always Free
license_model        = "LICENSE_INCLUDED"     # Free tier requirement
```

---

## 📦 Resources Created

| Resource                  | Specification        | Free Tier Limit               |
| ------------------------- | -------------------- | ----------------------------- |
| **Autonomous Database**   | 1 OCPU, 20GB storage | 2 per tenancy                 |
| **Object Storage Bucket** | Standard tier        | 20GB total across all buckets |
| **VCN & Networking**      | Basic networking     | Included in Always Free       |

---

## 🔍 Validation & Testing

### Validate Configuration

```bash
cd terraform
terraform init
terraform validate  # Check syntax and validation rules
terraform plan      # Preview changes
```

### Check Environment Variables

```bash
env | grep TF_VAR_  # View all Terraform variables
```

### Verify Always Free Tier Protection

```bash
cd terraform
terraform console
> var.cpu_core_count        # Should be 1
> var.is_free_tier         # Should be true
> var.storage_size_tbs     # Should be 0.02
```

---

## 📤 Outputs

After successful deployment:

```bash
terraform output  # View all outputs
```

**Available Outputs:**

- `database_id` - Database OCID
- `database_name` - Database name
- `database_connection_strings` - Connection URLs
- `admin_username` - Admin username (ADMIN)
- `admin_password` - Admin password (sensitive)
- `service_console_url` - OCI Console URL
- `bucket_name` - Object Storage bucket name
- `wallet_download_url` - Database wallet URL

---

## 🧹 Cleanup

### Destroy Resources

```bash
cd terraform
terraform destroy
```

**Note:** Database has `prevent_destroy` lifecycle rule. To destroy:

1. Comment out `prevent_destroy` in `main.tf`
2. Run `terraform apply` to update state
3. Run `terraform destroy`

### Or use Ansible for safe cleanup:

```bash
cd ../ansible
ansible-playbook playbooks/cleanup-resources.yml
```

---

## 📚 Helper Scripts Reference

### Local Development Scripts

| Script                     | Purpose                       | Usage                        |
| -------------------------- | ----------------------------- | ---------------------------- |
| `setup-env-vars.sh`        | Interactive environment setup | `source ./setup-env-vars.sh` |
| `generate-tfvars.sh`       | Generate tfvars from env vars | `./generate-tfvars.sh`       |
| `terraform.tfvars.example` | Template/documentation        | Reference only               |

**Important:** These scripts are for **local development only**—not used in CI/CD.

### CI/CD (GitHub Actions)

- Uses `TF_VAR_*` directly from repository secrets
- No script execution or tfvars generation
- Terraform reads variables from environment automatically

---

## 🆘 Troubleshooting

### Issue: Missing Required Variable

```
Error: No value for required variable
```

**Solution:**

```bash
export TF_VAR_compartment_ocid="ocid1.compartment.oc1..aaaaaaaa..."
```

### Issue: Variables Not Persisting

**Solution:** Add to `~/.bashrc`:

```bash
echo 'export TF_VAR_compartment_ocid="ocid1..."' >> ~/.bashrc
source ~/.bashrc
```

### Issue: Invalid Free Tier Configuration

```
Error: cpu_core_count must be exactly 1 for Always Free tier
```

**Solution:** You cannot override Always Free protection. These values are hardcoded in `variables.tf`.

### Issue: GitHub Actions Linter Warnings

```
Context access might be invalid: OCI_COMPARTMENT_OCID
```

**Expected:** Local linters may show warnings for secrets. GitHub Actions resolves these at runtime.

---

## 📖 Additional Resources

- **[OCI Always Free Tier Documentation](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm)**
- **[Terraform Environment Variables](https://www.terraform.io/docs/configuration/variables.html#environment-variables)**
- **[GitHub Actions Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)**
- **Project-specific**: See `.env.template` for GitHub Actions setup

---

## 🎯 Summary

✅ **Security**: No hardcoded secrets  
✅ **Flexibility**: Environment-specific configuration  
✅ **Cost Protection**: Always Free tier enforced  
✅ **CI/CD Ready**: GitHub Actions integration  
✅ **Developer Friendly**: Interactive setup scripts  
✅ **Production Ready**: Ansible orchestration available

**Configuration Files:**

- `variables.tf` - Variable definitions with validation and defaults
- `main.tf` - Resource definitions with lifecycle protection
- `outputs.tf` - Output definitions
- `terraform.tfvars` - Local config (gitignored, optional)
- `terraform.tfvars.example` - Template/documentation

**The configuration is secure, flexible, and cost-protected!** 🎉
