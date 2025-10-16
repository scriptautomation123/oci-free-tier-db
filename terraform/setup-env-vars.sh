#!/bin/bash

# ==============================================================================
# Environment Variable Setup Script for OCI Free Tier Database Suite
# ==============================================================================
# LOCAL DEVELOPMENT ONLY - Not used in CI/CD (GitHub Actions uses secrets)
# ==============================================================================
# This script helps you set up the required environment variables
# for Terraform deployment without hardcoding values in tfvars files.
# ==============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=============================================================================="
echo -e "🚀 OCI Free Tier Database Suite - Environment Setup"
echo -e "==============================================================================${NC}"
echo ""

# Function to prompt for input with validation
prompt_for_value() {
    local var_name="$1"
    local description="$2"
    local default_value="${3:-}"
    local is_required="${4:-true}"
    local is_sensitive="${5:-false}"
    
    local current_value="${!var_name:-}"
    
    echo -e "${YELLOW}📝 ${description}${NC}"
    if [ -n "$current_value" ]; then
        if [ "$is_sensitive" = "true" ]; then
            echo -e "${GREEN}   Current: [HIDDEN]${NC}"
        else
            echo -e "${GREEN}   Current: ${current_value}${NC}"
        fi
    fi
    
    if [ -n "$default_value" ]; then
        echo -e "${BLUE}   Default: ${default_value}${NC}"
    fi
    
    if [ "$is_sensitive" = "true" ]; then
        read -s -p "   Enter value (or press Enter to keep current): " user_input
        echo ""
    else
        read -p "   Enter value (or press Enter to keep current/default): " user_input
    fi
    
    if [ -n "$user_input" ]; then
        export "$var_name"="$user_input"
        echo "export $var_name=\"$user_input\"" >> ~/.bashrc
        echo -e "${GREEN}   ✅ Set $var_name${NC}"
    elif [ -n "$current_value" ]; then
        echo -e "${GREEN}   ✅ Keeping current value for $var_name${NC}"
    elif [ -n "$default_value" ]; then
        export "$var_name"="$default_value"
        echo "export $var_name=\"$default_value\"" >> ~/.bashrc
        echo -e "${GREEN}   ✅ Using default value for $var_name${NC}"
    elif [ "$is_required" = "true" ]; then
        echo -e "${RED}   ❌ ERROR: $var_name is required!${NC}"
        exit 1
    fi
    echo ""
}

# Check if running in supported environment
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo -e "${YELLOW}⚠️  This script should be sourced, not executed directly.${NC}"
    echo -e "${YELLOW}   Run: source ./setup-env-vars.sh${NC}"
    echo ""
fi

# Backup current bashrc
cp ~/.bashrc ~/.bashrc.backup.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true

echo -e "${BLUE}🔧 Setting up required environment variables...${NC}"
echo ""

# ==============================================================================
# REQUIRED VARIABLES
# ==============================================================================

echo -e "${BLUE}📋 REQUIRED CONFIGURATION${NC}"
echo ""

# OCI Compartment OCID (Required)
prompt_for_value "TF_VAR_compartment_ocid" \
    "OCI Compartment OCID (where resources will be created)" \
    "" \
    true \
    false

# OCI Region (Optional with default)
prompt_for_value "TF_VAR_region" \
    "OCI Region for deployment" \
    "us-ashburn-1" \
    false \
    false

# ==============================================================================
# DATABASE CONFIGURATION
# ==============================================================================

echo -e "${BLUE}🗄️  DATABASE CONFIGURATION${NC}"
echo ""

# Database Name (Optional with default)
prompt_for_value "TF_VAR_db_name" \
    "Database name (1-8 characters, start with letter)" \
    "PARTTEST" \
    false \
    false

# Database Version (Optional with default)
prompt_for_value "TF_VAR_db_version" \
    "Oracle Database version (19c, 21c, 23c)" \
    "19c" \
    false \
    false

# Admin Password (Optional - auto-generated if not provided)
prompt_for_value "TF_VAR_admin_password" \
    "Database admin password (12-30 chars, mixed case, numbers, #_)" \
    "" \
    false \
    true

# ==============================================================================
# ENVIRONMENT AND FEATURES
# ==============================================================================

echo -e "${BLUE}🏷️  ENVIRONMENT AND FEATURES${NC}"
echo ""

# Environment Name
prompt_for_value "TF_VAR_environment_name" \
    "Environment name for resource tagging" \
    "partition-test" \
    false \
    false

# Create Storage Bucket
prompt_for_value "TF_VAR_create_storage_bucket" \
    "Create Object Storage bucket (true/false)" \
    "true" \
    false \
    false

# Load Test Data
prompt_for_value "TF_VAR_load_test_data" \
    "Load test data into database (true/false)" \
    "false" \
    false \
    false

# Run Validation Tests
prompt_for_value "TF_VAR_run_validation_tests" \
    "Run validation tests after deployment (true/false)" \
    "false" \
    false \
    false

# Test Data Size
if [ "${TF_VAR_load_test_data:-false}" = "true" ]; then
    prompt_for_value "TF_VAR_test_data_size" \
        "Test data size (small, medium, large)" \
        "small" \
        false \
        false
fi

# ==============================================================================
# OPTIONAL ADVANCED CONFIGURATION
# ==============================================================================

echo ""
read -p "🔧 Configure advanced options? (y/N): " configure_advanced

if [[ "$configure_advanced" =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "${BLUE}⚙️  ADVANCED CONFIGURATION${NC}"
    echo ""
    
    # Backup Retention Days
    prompt_for_value "TF_VAR_backup_retention_days" \
        "Backup retention period in days (1-60)" \
        "7" \
        false \
        false
    
    # Whitelisted IPs
    prompt_for_value "TF_VAR_whitelisted_ips" \
        "Whitelisted IP addresses (JSON array format, e.g., [\"203.0.113.0/24\"])" \
        "[]" \
        false \
        false
    
    # Wallet Password
    prompt_for_value "TF_VAR_wallet_password" \
        "Wallet password (leave empty to use admin password)" \
        "" \
        false \
        true
fi

# ==============================================================================
# VALIDATION AND SUMMARY
# ==============================================================================

echo -e "${BLUE}=============================================================================="
echo -e "✅ Environment Setup Complete!"
echo -e "==============================================================================${NC}"
echo ""

echo -e "${GREEN}📊 Configuration Summary:${NC}"
echo -e "   Region: ${TF_VAR_region:-[using default]}"
echo -e "   Database: ${TF_VAR_db_name:-[using default]} (${TF_VAR_db_version:-[using default]})"
echo -e "   Environment: ${TF_VAR_environment_name:-[using default]}"
echo -e "   Storage Bucket: ${TF_VAR_create_storage_bucket:-[using default]}"
echo -e "   Test Data: ${TF_VAR_load_test_data:-[using default]}"
echo ""

echo -e "${YELLOW}📋 Next Steps:${NC}"
echo "   1. Review your configuration above"
echo "   2. Run: cd terraform && terraform plan"
echo "   3. Run: terraform apply (if plan looks good)"
echo ""

echo -e "${BLUE}💡 Tips:${NC}"
echo "   • Your settings are saved to ~/.bashrc and will persist"
echo "   • Run 'source ~/.bashrc' in new terminals to load variables"
echo "   • Use 'env | grep TF_VAR_' to see all Terraform variables"
echo "   • Re-run this script anytime to update configuration"
echo ""

echo -e "${GREEN}🎉 Ready for deployment! Environment variables are configured.${NC}"