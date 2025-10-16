# ==============================================================================
# ALWAYS FREE TIER CONFIGURATION (RECOMMENDED)
# ==============================================================================

# IMPORTANT: This configuration is optimized for Oracle Always Free tier
# to prevent any charges. Only modify if you understand the cost implications.

# Acknowledge that you understand Always Free tier limitations
acknowledge_free_tier_limits = true

# ==============================================================================
# REQUIRED: OCI Configuration (Set via Environment Variables)
# ==============================================================================

# Your OCI compartment OCID where resources will be created
# Set via environment variable: export TF_VAR_compartment_ocid="ocid1.compartment.oc1..aaaaaaaa..."
# Or set in CI/CD secrets as OCI_COMPARTMENT_OCID
compartment_ocid = null  # Will be provided via TF_VAR_compartment_ocid environment variable

# OCI region for deployment
# Set via environment variable: export TF_VAR_region="us-ashburn-1"
region = null  # Will be provided via TF_VAR_region environment variable or use default

# ==============================================================================
# DATABASE CONFIGURATION (ALWAYS FREE OPTIMIZED)
# ==============================================================================

# Database name (1-8 characters, start with letter)
# Set via environment variable: export TF_VAR_db_name="PARTTEST"
db_name = null  # Will use default from variables.tf or environment variable

# Oracle Database version
# Set via environment variable: export TF_VAR_db_version="19c"
db_version = null  # Will use default from variables.tf or environment variable

# Admin password (leave empty for auto-generation)
# Must be 12-30 chars with uppercase, lowercase, number, and special char (#, _)
# Set via environment variable: export TF_VAR_admin_password="YourSecurePassword123#"
# Or use auto-generation by leaving empty
admin_password = ""  # Auto-generated or via TF_VAR_admin_password environment variable

# ==============================================================================
# ALWAYS FREE TIER LIMITS (DO NOT CHANGE UNLESS YOU WANT CHARGES)
# ==============================================================================

# CPU cores - Always Free allows exactly 1 OCPU
cpu_core_count = 1

# Storage - Always Free allows up to 20GB (0.02 TB)
storage_size_tbs = 0.02

# Auto-scaling MUST be disabled for Always Free tier
auto_scaling_enabled = false

# Use Always Free tier (STRONGLY RECOMMENDED)
is_free_tier = true

# License model (Always Free uses LICENSE_INCLUDED)
license_model = "LICENSE_INCLUDED"

# ==============================================================================
# SECURITY AND BACKUP
# ==============================================================================

# Backup retention period (1-60 days)
backup_retention_days = 7

# IP addresses allowed to connect (empty list = allow all)
# Example: ["203.0.113.0/24", "198.51.100.1/32"]
whitelisted_ips = []

# ==============================================================================
# ENVIRONMENT AND TAGGING
# ==============================================================================

# Environment name for resource tagging
# Set via environment variable: export TF_VAR_environment_name="my-test-env"
environment_name = null  # Will use default from variables.tf or environment variable

# ==============================================================================
# OPTIONAL FEATURES
# ==============================================================================

# Create Object Storage bucket for backups/exports
# Set via environment variable: export TF_VAR_create_storage_bucket=true
create_storage_bucket = null  # Will use default from variables.tf or environment variable

# Testing configuration
# Set via environment variables:
# export TF_VAR_load_test_data=true
# export TF_VAR_run_validation_tests=true
# export TF_VAR_test_data_size="medium"
load_test_data       = null  # Will use default from variables.tf or environment variable
run_validation_tests = null  # Will use default from variables.tf or environment variable
test_data_size       = null  # Will use default from variables.tf or environment variable

# ==============================================================================
# ADVANCED CONFIGURATION (Uncomment to customize)
# ==============================================================================

# Wallet password (if different from admin password)
# wallet_password = ""