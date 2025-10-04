# Oracle Cloud Infrastructure (OCI) Automation

🚨 **ALWAYS FREE TIER PROTECTION** - Zero cost Oracle Cloud automation for partition management suite testing

## Overview

This directory contains complete automation scripts for deploying the Oracle Partition Management Suite on Oracle Cloud Infrastructure using **Always Free tier resources only**. All scripts include multiple safety checks to prevent accidental charges.

## 🚀 Quick Start (One Command)

```bash
# Complete end-to-end deployment
./scripts/deploy-complete-suite.sh
```

This single command will:
- ✅ Install and configure OCI CLI and Terraform
- ✅ Create Always Free Oracle Autonomous Database
- ✅ Deploy partition management packages
- ✅ Load test data and run validation
- ✅ Provide complete connection information
- ✅ **ZERO COST** - Always Free tier only

## 📁 Directory Structure

```
oci/
├── scripts/                     # Automation scripts
│   ├── deploy-complete-suite.sh # 🎯 MAIN SCRIPT - Complete deployment
│   ├── setup-oci-cli.sh        # OCI CLI and Terraform setup
│   ├── create-test-database.sh  # Database creation only
│   └── cleanup-resources.sh     # Safe resource cleanup
├── terraform/                   # Infrastructure as Code
│   ├── main.tf                 # Resource definitions
│   ├── variables.tf            # Configuration variables
│   └── outputs.tf              # Connection information
├── config/                      # Configuration files
│   ├── terraform.tfvars.example # Configuration template
│   └── terraform.tfvars        # Your OCI settings
├── test-data/                   # Sample data scripts
├── wallet/                      # Database wallet (auto-created)
└── logs/                       # Deployment logs
```

## 🛡️ Always Free Tier Protection

### Resource Limits (Enforced)
- **Database**: 1 OCPU, 20GB storage, no auto-scaling
- **Storage**: 20GB Object Storage bucket
- **Cost**: $0.00/month permanently
- **Time Limit**: None

### Safety Features
- ✅ Multiple configuration validations
- ✅ Resource limit enforcement
- ✅ Cost monitoring tags
- ✅ Prevent accidental upgrades
- ✅ Lifecycle protection rules

## 📋 Prerequisites

1. **Oracle Cloud Account**
   - Always Free tier eligible account
   - Home region selected
   - Proper IAM permissions

2. **System Requirements**
   - Linux/macOS/WSL
   - Internet connection
   - 2GB free disk space

3. **Required Information**
   - User OCID
   - Tenancy OCID
   - Compartment OCID
   - Region name

## 🚀 Deployment Options

### Option 1: Complete Automation (Recommended)
```bash
# Single command for everything
./scripts/deploy-complete-suite.sh

# Includes help information
./scripts/deploy-complete-suite.sh --help
```

### Option 2: Step-by-Step Deployment
```bash
# 1. Setup environment
./scripts/setup-oci-cli.sh

# 2. Edit configuration
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Edit terraform.tfvars with your OCI details

# 3. Create database
./scripts/create-test-database.sh

# 4. Connect and install packages manually
# (Connection details provided after database creation)
```

### Option 3: Infrastructure Only
```bash
# Just create the database, no package installation
./scripts/create-test-database.sh
```

## ⚙️ Configuration

### Required Settings (terraform.tfvars)
```hcl
# Always Free tier acknowledgment (REQUIRED)
acknowledge_free_tier_limits = true

# OCI connection details (REQUIRED)
compartment_ocid = "ocid1.compartment.oc1..your-compartment-ocid"
region = "us-ashburn-1"

# Database settings (DO NOT CHANGE for Always Free)
cpu_core_count = 1
storage_size_tbs = 0.02
auto_scaling_enabled = false
is_free_tier = true
license_model = "LICENSE_INCLUDED"

# Optional settings
environment_name = "partition-test"
admin_password = ""  # Auto-generated if empty
create_storage_bucket = true
```

### Critical Settings (DO NOT MODIFY)
These settings are enforced to prevent charges:
- `cpu_core_count = 1` (Always Free limit)
- `storage_size_tbs = 0.02` (20GB Always Free limit)
- `auto_scaling_enabled = false` (Prevents auto-charges)
- `is_free_tier = true` (Forces Always Free tier)

## 🔗 Connection Information

After deployment, you'll receive:

### Web Interfaces
- **SQL Developer Web**: Full SQL IDE in browser
- **APEX**: Application development platform
- **Service Console**: Database monitoring and management

### Database Connection
```bash
# Direct connection (replace with actual values)
sqlplus ADMIN/[password]@PARTTEST_HIGH

# With wallet (most secure)
export TNS_ADMIN=/path/to/wallet
sqlplus ADMIN/[password]@PARTTEST_HIGH
```

### Connection Details File
All connection information is saved to:
- `oci/connection-details.txt`
- Includes passwords, URLs, and quick-start commands

## 🧪 Testing and Validation

### Included Test Data
- Sample partitioned tables
- Configuration examples
- Validation test suite

### Running Tests
```bash
# After deployment, tests run automatically
# Manual test execution:
sqlplus ADMIN/[password]@PARTTEST_HIGH @../ddl-generator/5_examples/comprehensive_usage_examples.sql
```

## 🧹 Cleanup

### Safe Resource Removal
```bash
# Complete cleanup with confirmations
./scripts/cleanup-resources.sh

# Includes data export option
# Creates automatic backups
# Restores Always Free tier quota
```

### What Gets Removed
- Oracle Autonomous Database (and ALL data)
- Object Storage bucket and contents
- All networking resources
- Local Terraform state and wallet files

### What Gets Backed Up
- Configuration files
- Connection details
- Terraform state (for reference)
- Database wallet

## 🔧 Troubleshooting

### Common Issues

1. **"OCI CLI not found"**
   ```bash
   # Run setup script
   ./scripts/setup-oci-cli.sh
   ```

2. **"Compartment OCID not found"**
   - Get from OCI Console → Identity → Compartments
   - Use root compartment if unsure

3. **"Always Free database limit exceeded"**
   - Maximum 2 Always Free databases per tenancy
   - Delete unused databases or use existing ones

4. **"Permission denied"**
   - Ensure user has proper IAM policies
   - Check compartment-level permissions

5. **"Terraform state lock"**
   ```bash
   cd oci/terraform
   terraform force-unlock [LOCK_ID]
   ```

### Log Files
- **Deployment**: `oci/logs/deployment-[timestamp].log`
- **Terraform**: `oci/terraform/terraform.log`
- **Database**: Connection logs in wallet directory

### Getting Help
```bash
# Script help
./scripts/deploy-complete-suite.sh --help
./scripts/cleanup-resources.sh --help

# Terraform help
cd oci/terraform
terraform plan --help
terraform apply --help
```

## 🔒 Security Best Practices

### Database Security
- ✅ Admin password auto-generated (16+ characters)
- ✅ Database wallet for secure connections
- ✅ Network access controls
- ✅ Audit logging enabled

### Credential Management
- Passwords stored in Terraform state (encrypted)
- Wallet files in local directory only
- No credentials in version control

### Access Control
- Use database wallet for connections
- Rotate passwords regularly
- Monitor access through service console

## 💰 Cost Monitoring

### Always Free Tier Benefits
- **Cost**: $0.00/month permanently
- **Resources**: 2 databases (1 OCPU, 20GB each)
- **Storage**: 20GB Object Storage per region
- **No Expiration**: Resources never expire

### Cost Protection Features
- ✅ Resource limit validation
- ✅ Auto-scaling disabled
- ✅ Cost monitoring tags
- ✅ Prevent_destroy lifecycle rules
- ✅ Multiple confirmation prompts

### Monitoring Usage
```bash
# Check current resource usage
oci limits resource-availability get --compartment-id [COMPARTMENT_OCID] --service-name "database"

# View Always Free tier usage
# Check OCI Console → Account Management → Usage
```

## 🚨 Important Notes

### Always Free Tier Limits
- **Maximum 2 Autonomous Databases** per tenancy
- **1 OCPU, 20GB storage** per database
- **20GB Object Storage** per region
- **No time limits** - resources are permanent

### Data Backup
- Always Free tier includes automated backups
- Export important data before cleanup
- Use Object Storage for additional backups

### Upgrade Considerations
- Upgrading from Always Free tier incurs charges
- All scripts prevent accidental upgrades
- Contact Oracle for upgrade assistance

## 📚 Additional Resources

### Oracle Documentation
- [Always Free Tier Overview](https://www.oracle.com/cloud/free/)
- [Autonomous Database Documentation](https://docs.oracle.com/en/cloud/paas/autonomous-database/)
- [OCI CLI Documentation](https://docs.oracle.com/en-us/iaas/tools/oci-cli/)

### Partition Management Suite
- **Main Documentation**: `../ddl-generator/README.md`
- **API Reference**: `../ddl-generator/6_documentation/API_REFERENCE.md`
- **Examples**: `../ddl-generator/5_examples/`

### Support
- GitHub Issues: [Project Repository]
- Oracle Support: [Always Free tier eligible]
- Community Forums: [Oracle Cloud Community]

---

## 🎉 Success Criteria

After successful deployment, you should have:
- ✅ Oracle Autonomous Database (Always Free tier)
- ✅ Complete partition management suite installed
- ✅ Test data loaded and validated
- ✅ Web interfaces accessible
- ✅ Database wallet configured
- ✅ Zero ongoing costs

**Ready to start partitioning? Connect to your database and explore the examples!**