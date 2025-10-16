#!/bin/bash

# ==============================================================================
# Generate terraform.tfvars from Environment Variables
# ==============================================================================
# LOCAL DEVELOPMENT ONLY - Not used in CI/CD (GitHub Actions uses TF_VAR_* directly)
# ==============================================================================
# This script generates a terraform.tfvars file from environment variables
# Useful when you prefer working with a tfvars file locally vs. environment variables
# ==============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

TFVARS_FILE="terraform.tfvars"
BACKUP_FILE="terraform.tfvars.backup.$(date +%Y%m%d_%H%M%S)"

echo -e "${BLUE}=============================================================================="
echo -e "🔧 Generating terraform.tfvars from Environment Variables"
echo -e "==============================================================================${NC}"

# Backup existing tfvars if it exists
if [ -f "$TFVARS_FILE" ]; then
    echo -e "${YELLOW}📁 Backing up existing terraform.tfvars to $BACKUP_FILE${NC}"
    cp "$TFVARS_FILE" "$BACKUP_FILE"
fi

# Start generating the new tfvars file
cat > "$TFVARS_FILE" << 'EOF'
# ==============================================================================
# GENERATED terraform.tfvars - DO NOT EDIT MANUALLY
# ==============================================================================
# This file was generated from environment variables using generate-tfvars.sh
# To modify values, update environment variables and re-run the generator
# Generated on: $(date)
# ==============================================================================

# ALWAYS FREE TIER PROTECTION
acknowledge_free_tier_limits = true

# ALWAYS FREE TIER LIMITS (NEVER CHANGE TO AVOID CHARGES)
cpu_core_count        = 1
storage_size_tbs      = 0.02
auto_scaling_enabled  = false
is_free_tier         = true
license_model        = "LICENSE_INCLUDED"

EOF

# Function to add variable to tfvars if environment variable exists
add_var_if_set() {
    local env_var="$1"
    local tf_var="$2"
    local var_type="${3:-string}"
    local description="$4"
    
    local value="${!env_var:-}"
    
    if [ -n "$value" ]; then
        echo "# $description" >> "$TFVARS_FILE"
        if [ "$var_type" = "string" ]; then
            echo "$tf_var = \"$value\"" >> "$TFVARS_FILE"
        else
            echo "$tf_var = $value" >> "$TFVARS_FILE"
        fi
        echo "" >> "$TFVARS_FILE"
        echo -e "${GREEN}✅ Set $tf_var from $env_var${NC}"
    else
        echo -e "${YELLOW}⚠️  $env_var not set - using default${NC}"
    fi
}

# Check for required variables
echo -e "${BLUE}🔍 Checking required environment variables...${NC}"

if [ -z "${TF_VAR_compartment_ocid:-}" ]; then
    echo -e "${RED}❌ ERROR: TF_VAR_compartment_ocid is required!${NC}"
    echo -e "${YELLOW}   Set it with: export TF_VAR_compartment_ocid=\"ocid1.compartment.oc1..aaaaaaaa...\"${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Required variables validated${NC}"
echo ""

# Add configuration section headers and variables
echo -e "${BLUE}📝 Generating configuration...${NC}"

# Required OCI Configuration
echo "# =============================================================================="  >> "$TFVARS_FILE"
echo "# OCI CONFIGURATION"  >> "$TFVARS_FILE"
echo "# =============================================================================="  >> "$TFVARS_FILE"
echo ""  >> "$TFVARS_FILE"

add_var_if_set "TF_VAR_compartment_ocid" "compartment_ocid" "string" "OCI Compartment OCID"
add_var_if_set "TF_VAR_region" "region" "string" "OCI Region"

# Database Configuration
echo "# =============================================================================="  >> "$TFVARS_FILE"
echo "# DATABASE CONFIGURATION"  >> "$TFVARS_FILE"
echo "# =============================================================================="  >> "$TFVARS_FILE"
echo ""  >> "$TFVARS_FILE"

add_var_if_set "TF_VAR_db_name" "db_name" "string" "Database name"
add_var_if_set "TF_VAR_db_version" "db_version" "string" "Database version"
add_var_if_set "TF_VAR_admin_password" "admin_password" "string" "Admin password (leave empty for auto-generation)"

# Environment and Tagging
echo "# =============================================================================="  >> "$TFVARS_FILE"
echo "# ENVIRONMENT AND TAGGING"  >> "$TFVARS_FILE"
echo "# =============================================================================="  >> "$TFVARS_FILE"
echo ""  >> "$TFVARS_FILE"

add_var_if_set "TF_VAR_environment_name" "environment_name" "string" "Environment name"

# Optional Features
echo "# =============================================================================="  >> "$TFVARS_FILE"
echo "# OPTIONAL FEATURES"  >> "$TFVARS_FILE"
echo "# =============================================================================="  >> "$TFVARS_FILE"
echo ""  >> "$TFVARS_FILE"

add_var_if_set "TF_VAR_create_storage_bucket" "create_storage_bucket" "bool" "Create storage bucket"

# Testing Configuration
add_var_if_set "TF_VAR_load_test_data" "load_test_data" "bool" "Load test data"
add_var_if_set "TF_VAR_run_validation_tests" "run_validation_tests" "bool" "Run validation tests"
add_var_if_set "TF_VAR_test_data_size" "test_data_size" "string" "Test data size"

# Security and Backup
echo "# =============================================================================="  >> "$TFVARS_FILE"
echo "# SECURITY AND BACKUP"  >> "$TFVARS_FILE"
echo "# =============================================================================="  >> "$TFVARS_FILE"
echo ""  >> "$TFVARS_FILE"

add_var_if_set "TF_VAR_backup_retention_days" "backup_retention_days" "number" "Backup retention days"
add_var_if_set "TF_VAR_whitelisted_ips" "whitelisted_ips" "list" "Whitelisted IP addresses"
add_var_if_set "TF_VAR_wallet_password" "wallet_password" "string" "Wallet password"

echo ""
echo -e "${GREEN}=============================================================================="
echo -e "✅ terraform.tfvars generated successfully!"
echo -e "==============================================================================${NC}"
echo ""

echo -e "${BLUE}📊 Generated Configuration Summary:${NC}"
echo -e "   File: $TFVARS_FILE"
echo -e "   Backup: $BACKUP_FILE (if existed)"
echo -e "   Source: Environment variables (TF_VAR_*)"
echo ""

echo -e "${YELLOW}📋 Next Steps:${NC}"
echo "   1. Review generated terraform.tfvars"
echo "   2. Run: terraform plan"
echo "   3. Run: terraform apply (if plan looks good)"
echo ""

echo -e "${BLUE}💡 Tips:${NC}"
echo "   • Variables not set in environment will use defaults from variables.tf"
echo "   • Always Free tier protection is automatically included"
echo "   • Re-run this script anytime to regenerate from current environment"
echo ""