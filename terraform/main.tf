# Oracle Partition Management Suite - Infrastructure
# Terraform configuration for Oracle Cloud Database testing

terraform {
  required_version = ">= 1.0"
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 5.0"
    }
  }
}

# Configure the Oracle Cloud Infrastructure Provider
provider "oci" {
  region = var.region
}

# Data source for availability domains
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_ocid
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
  compartment_id           = var.compartment_ocid
  cpu_core_count          = 1
  data_storage_size_in_gb = 20
  
  # Database configuration
  db_name      = var.db_name
  display_name = "${var.environment_name}-partition-test-db"
  
  # Oracle version - use 19c for partition features
  db_version = "19c"
  
  # Admin credentials
  admin_password = var.admin_password != "" ? var.admin_password : random_password.admin_password[0].result
  
  # Always Free Tier Essential Settings
  is_auto_scaling_enabled = false
  is_free_tier           = true
  license_model          = "LICENSE_INCLUDED"
  
  # Always Free Tier Tags
  freeform_tags = {
    "Environment" = var.environment_name
    "Project"     = "Oracle-Partition-Suite"
    "Purpose"     = "Testing"
    "Tier"        = "Always-Free"
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
  }
}

# Database wallet resource (conditionally created)
resource "oci_database_autonomous_database_wallet" "partition_test_wallet" {
  count = var.create_wallet ? 1 : 0
  
  autonomous_database_id = oci_database_autonomous_database.partition_test_db.id
  password              = var.wallet_password != "" ? var.wallet_password : (var.admin_password != "" ? var.admin_password : random_password.admin_password[0].result)
  base64_encode_content = true
  
  # Generate filename for local storage
  generate_type = "SINGLE"
}

# Object Storage bucket for backups and exports (Always Free: 20GB limit)
resource "oci_objectstorage_bucket" "partition_test_bucket" {
  count          = var.create_storage_bucket ? 1 : 0
  compartment_id = var.compartment_ocid
  name           = "${var.environment_name}-partition-test-bucket"
  namespace      = data.oci_objectstorage_namespace.ns.namespace
  
  access_type = "NoPublicAccess"
  
  # Versioning disabled for Always Free to save space
  versioning = var.is_free_tier ? "Disabled" : "Enabled"
  
  freeform_tags = merge({
    "Environment" = var.environment_name
    "Project"     = "Oracle-Partition-Suite"
    "Purpose"     = "Testing-Storage"
    "Tier"        = var.is_free_tier ? "Always-Free" : "Paid"
  }, var.is_free_tier ? {
    "FREE_TIER_LIMIT" = "20GB-Max"
    "WARNING" = "Monitor-Usage-To-Stay-Free"
  } : {})
}

# Data source for object storage namespace
data "oci_objectstorage_namespace" "ns" {
  compartment_id = var.compartment_ocid
}