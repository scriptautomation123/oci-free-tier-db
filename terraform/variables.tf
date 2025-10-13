# Variables for Oracle Partition Management Suite Infrastructure

# Required Variables
variable "compartment_ocid" {
  description = "The OCID of the compartment where resources will be created"
  type        = string
}

variable "region" {
  description = "The OCI region where resources will be created"
  type        = string
  default     = "us-ashburn-1"
}

# Database Configuration
variable "db_name" {
  description = "The database name for the Autonomous Database"
  type        = string
  default     = "PARTTEST"

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9_]{0,7}$", var.db_name))
    error_message = "Database name must start with a letter and be 1-8 characters long, containing only letters, numbers, and underscores."
  }
}

variable "db_version" {
  description = "The Oracle Database version"
  type        = string
  default     = "19c"

  validation {
    condition     = contains(["19c", "21c", "23c"], var.db_version)
    error_message = "Database version must be one of: 19c, 21c, 23c."
  }
}

variable "admin_password" {
  description = "The admin password for the database (leave empty for auto-generation)"
  type        = string
  default     = ""
  sensitive   = true

  validation {
    condition = var.admin_password == "" || (
      length(var.admin_password) >= 12 &&
      length(var.admin_password) <= 30 &&
      can(regex("[A-Z]", var.admin_password)) &&
      can(regex("[a-z]", var.admin_password)) &&
      can(regex("[0-9]", var.admin_password)) &&
      can(regex("[#_]", var.admin_password))
    )
    error_message = "Password must be 12-30 characters with at least one uppercase, lowercase, number, and special character (#, _)."
  }
}

variable "wallet_password" {
  description = "The wallet password (leave empty to use admin password)"
  type        = string
  default     = ""
  sensitive   = true
}

# Compute and Storage (Always Free Tier Limits)
variable "cpu_core_count" {
  description = "The number of CPU cores for the Autonomous Database (Always Free: max 1)"
  type        = number
  default     = 1

  validation {
    condition     = var.is_free_tier ? var.cpu_core_count == 1 : (var.cpu_core_count >= 1 && var.cpu_core_count <= 128)
    error_message = "For Always Free tier, CPU core count must be exactly 1. For paid tier, it can be 1-128."
  }
}

variable "storage_size_tbs" {
  description = "The storage size in terabytes (Always Free: max 0.02 TB = 20GB)"
  type        = number
  default     = 0.02

  validation {
    condition     = var.is_free_tier ? var.storage_size_tbs <= 0.02 : (var.storage_size_tbs >= 1 && var.storage_size_tbs <= 384)
    error_message = "For Always Free tier, storage must be ≤ 0.02 TB (20GB). For paid tier, it can be 1-384 TB."
  }
}

# Features and Options (Always Free Tier Configuration)
variable "auto_scaling_enabled" {
  description = "Enable auto-scaling for the database (Always Free: disabled)"
  type        = bool
  default     = false

  validation {
    condition     = var.is_free_tier ? var.auto_scaling_enabled == false : true
    error_message = "Auto-scaling must be disabled for Always Free tier to avoid charges."
  }
}

variable "is_free_tier" {
  description = "Use Oracle Always Free tier (RECOMMENDED to avoid charges)"
  type        = bool
  default     = true
}

variable "license_model" {
  description = "The license model (LICENSE_INCLUDED or BRING_YOUR_OWN_LICENSE)"
  type        = string
  default     = "LICENSE_INCLUDED"

  validation {
    condition     = contains(["LICENSE_INCLUDED", "BRING_YOUR_OWN_LICENSE"], var.license_model)
    error_message = "License model must be either LICENSE_INCLUDED or BRING_YOUR_OWN_LICENSE."
  }
}

# Backup and Security
variable "backup_retention_days" {
  description = "Number of days to retain automated backups"
  type        = number
  default     = 7

  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 60
    error_message = "Backup retention must be between 1 and 60 days."
  }
}

variable "whitelisted_ips" {
  description = "List of IP addresses allowed to connect to the database"
  type        = list(string)
  default     = []
}

# Environment and Tagging
variable "environment_name" {
  description = "The environment name for resource tagging"
  type        = string
  default     = "partition-test"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.environment_name))
    error_message = "Environment name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "project_name" {
  description = "The project name for resource tagging"
  type        = string
  default     = "Oracle-Partition-Suite"
}

variable "db_purpose" {
  description = "The purpose of the database for resource tagging"
  type        = string
  default     = "Testing"
}

variable "storage_purpose" {
  description = "The purpose of the storage bucket for resource tagging"
  type        = string
  default     = "Testing-Storage"
}

variable "db_name_suffix" {
  description = "The suffix for the database display name"
  type        = string
  default     = "partition-test-db"
}

variable "bucket_name_suffix" {
  description = "The suffix for the storage bucket name"
  type        = string
  default     = "partition-test-bucket"
}

# Optional Features
variable "create_storage_bucket" {
  description = "Create an Object Storage bucket for backups and exports (Always Free: 20GB limit)"
  type        = bool
  default     = true
}

variable "create_wallet" {
  description = "Create and download a database wallet file"
  type        = bool
  default     = false
}

variable "enable_object_events" {
  description = "Enable object events for the storage bucket (for security monitoring and auditing)"
  type        = bool
  default     = true
}

variable "enable_bucket_versioning" {
  description = "Enable versioning for the storage bucket (recommended for security, but uses additional storage on free tier)"
  type        = bool
  default     = true

  validation {
    condition     = !var.is_free_tier || var.enable_bucket_versioning == false || var.acknowledge_free_tier_limits == true
    error_message = "Enabling versioning on Always Free tier will consume additional storage. Set acknowledge_free_tier_limits=true to confirm you understand the storage implications."
  }
}

variable "kms_key_id" {
  description = "The OCID of the KMS key for Customer Managed Encryption (leave empty to use Oracle-managed encryption)"
  type        = string
  default     = null
  sensitive   = true
}

# Always Free Tier Validation
variable "enforce_free_tier" {
  description = "Enforce Always Free tier limits to prevent accidental charges"
  type        = bool
  default     = true
}

variable "acknowledge_free_tier_limits" {
  description = "Acknowledge understanding of Always Free tier limitations"
  type        = bool
  default     = false

  validation {
    condition     = var.is_free_tier ? var.acknowledge_free_tier_limits == true : true
    error_message = "You must acknowledge Always Free tier limits by setting acknowledge_free_tier_limits = true."
  }
}

# Testing and Validation Variables
variable "load_test_data" {
  description = "Whether to load test data into the database"
  type        = bool
  default     = false
}

variable "run_validation_tests" {
  description = "Whether to run validation tests after deployment"
  type        = bool
  default     = false
}

variable "test_data_size" {
  description = "Size of test data to generate (small, medium, large)"
  type        = string
  default     = "small"

  validation {
    condition     = contains(["small", "medium", "large"], var.test_data_size)
    error_message = "test_data_size must be one of: small, medium, large."
  }
}
