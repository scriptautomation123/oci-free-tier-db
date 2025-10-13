# Oracle Partition Management Suite - Infrastructure
# Terraform configuration for Oracle Cloud Database testing

terraform {
  required_version = ">= 1.0"
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

# Configure the Oracle Cloud Infrastructure Provider
provider "oci" {
  region = var.region
}

# Locals for computed values
locals {
  # Always Free tier safety checks
  is_free_tier_safe = var.is_free_tier && var.acknowledge_free_tier_limits

  # Computed storage in GB (convert from TB to GB)
  # Use floor() to avoid floating point precision issues
  storage_gb = floor(var.storage_size_tbs * 1024)

  # Free tier validation messages
  free_tier_warnings = var.is_free_tier ? [
    "Using Always Free tier configuration",
    "CPU cores: ${var.cpu_core_count} (max 1 for free tier)",
    "Storage: ${local.storage_gb}GB (max 20GB for free tier)",
    "Auto-scaling: ${var.auto_scaling_enabled ? "enabled" : "disabled"} (must be disabled for free tier)"
  ] : []

  # Project and purpose from variables
  project_name = var.project_name
  db_purpose   = var.db_purpose
}

# Random password generation for database
resource "random_password" "admin_password" {
  count   = var.admin_password == "" ? 1 : 0
  length  = 16
  special = true
  upper   = true
  lower   = true
  numeric = true
}

# Autonomous Database for partition testing (Always Free Tier Optimized)
resource "oci_database_autonomous_database" "partition_test_db" {
  compartment_id          = var.compartment_ocid
  cpu_core_count          = var.cpu_core_count
  data_storage_size_in_gb = local.storage_gb

  # Database configuration
  db_name      = var.db_name
  display_name = "${var.environment_name}-${var.db_name_suffix}"

  # Oracle version - use variable for flexibility
  db_version = var.db_version

  # Admin credentials
  admin_password = var.admin_password != "" ? var.admin_password : random_password.admin_password[0].result

  # Always Free Tier Essential Settings
  is_auto_scaling_enabled = var.auto_scaling_enabled
  is_free_tier            = var.is_free_tier
  license_model           = var.license_model

  # Backup configuration
  backup_retention_period_in_days = var.backup_retention_days

  # Network access control
  whitelisted_ips = length(var.whitelisted_ips) > 0 ? var.whitelisted_ips : null

  # Always Free Tier Tags
  freeform_tags = {
    "Environment" = var.environment_name
    "Project"     = local.project_name
    "Purpose"     = local.db_purpose
    "Tier"        = var.is_free_tier ? "Always-Free" : "Paid"
  }

  # Lifecycle management - Critical for Always Free tier
  lifecycle {
    # Prevent accidental upgrade from free tier
    prevent_destroy = true

    # Ignore changes that could trigger expensive updates
    ignore_changes = [
      cpu_core_count,
      data_storage_size_in_gb,
      is_auto_scaling_enabled,
      is_free_tier,
      license_model
    ]

    # Validate free tier acknowledgment
    precondition {
      condition     = !var.is_free_tier || local.is_free_tier_safe
      error_message = "You must acknowledge Always Free tier limits by setting acknowledge_free_tier_limits = true in terraform.tfvars"
    }

    # Free tier enforcement preconditions
    precondition {
      condition     = !var.enforce_free_tier || (var.is_free_tier == true)
      error_message = "When enforce_free_tier is enabled, is_free_tier must be true."
    }

    precondition {
      condition     = !var.enforce_free_tier || (var.cpu_core_count <= 1)
      error_message = "When enforce_free_tier is enabled, cpu_core_count must not exceed 1."
    }

    precondition {
      condition     = !var.enforce_free_tier || (local.storage_gb <= 20)
      error_message = "When enforce_free_tier is enabled, storage must not exceed 20GB."
    }
  }
}

# Database wallet resource (conditionally created)
resource "oci_database_autonomous_database_wallet" "partition_test_wallet" {
  count = var.create_wallet ? 1 : 0

  autonomous_database_id = oci_database_autonomous_database.partition_test_db.id
  password               = var.wallet_password != "" ? var.wallet_password : (var.admin_password != "" ? var.admin_password : random_password.admin_password[0].result)
  base64_encode_content  = true

  # Generate filename for local storage
  generate_type = "SINGLE"
}

# Object Storage bucket for backups and exports (Always Free: 20GB limit)
resource "oci_objectstorage_bucket" "partition_test_bucket" {
  count          = var.create_storage_bucket ? 1 : 0
  compartment_id = var.compartment_ocid
  name           = "${var.environment_name}-${var.bucket_name_suffix}"
  namespace      = data.oci_objectstorage_namespace.ns.namespace

  access_type = "NoPublicAccess"

  # Versioning configuration (can be overridden, but aware of storage limits on free tier)
  versioning = var.enable_bucket_versioning ? "Enabled" : "Disabled"

  # Enable object events for security monitoring
  object_events_enabled = var.enable_object_events

  # Customer Managed Key encryption (optional, for enhanced security)
  kms_key_id = var.kms_key_id

  freeform_tags = merge({
    "Environment"     = var.environment_name
    "Project"         = local.project_name
    "Purpose"         = var.storage_purpose
    "Tier"            = var.is_free_tier ? "Always-Free" : "Paid"
    "LoadTestData"    = var.load_test_data ? "enabled" : "disabled"
    "ValidationTests" = var.run_validation_tests ? "enabled" : "disabled"
    "TestDataSize"    = var.test_data_size
    }, var.is_free_tier ? {
    "FREE_TIER_LIMIT" = "20GB-Max"
    "WARNING"         = "Monitor-Usage-To-Stay-Free"
  } : {})
}

# Data source for object storage namespace
data "oci_objectstorage_namespace" "ns" {
  compartment_id = var.compartment_ocid
}
