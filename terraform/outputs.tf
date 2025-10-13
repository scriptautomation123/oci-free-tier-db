# Outputs for Oracle Partition Management Suite Infrastructure

# Free Tier Validation Information
output "free_tier_warnings" {
  description = "Free tier configuration warnings and validation messages"
  value       = local.free_tier_warnings
}

# Database Connection Information
output "database_id" {
  description = "The OCID of the Autonomous Database"
  value       = oci_database_autonomous_database.partition_test_db.id
}

output "database_name" {
  description = "The name of the database"
  value       = oci_database_autonomous_database.partition_test_db.db_name
}

output "database_version" {
  description = "The Oracle Database version"
  value       = oci_database_autonomous_database.partition_test_db.db_version
}

# Connection URLs and Endpoints
output "connection_urls" {
  description = "Database connection URLs"
  value = {
    sql_developer_web = try(oci_database_autonomous_database.partition_test_db.connection_urls[0].sql_dev_web_url, "")
    apex_url          = try(oci_database_autonomous_database.partition_test_db.connection_urls[0].apex_url, "")
    machine_learning  = try(oci_database_autonomous_database.partition_test_db.connection_urls[0].machine_learning_user_management_url, "")
    ords_url          = try(oci_database_autonomous_database.partition_test_db.connection_urls[0].ords_url, "")
  }
}

output "service_console_url" {
  description = "The service console URL for the database"
  value       = oci_database_autonomous_database.partition_test_db.service_console_url
}

# Connection Strings
output "connection_strings" {
  description = "Database connection strings"
  value = {
    high     = lookup(oci_database_autonomous_database.partition_test_db.connection_strings[0].all_connection_strings, "HIGH", "")
    medium   = lookup(oci_database_autonomous_database.partition_test_db.connection_strings[0].all_connection_strings, "MEDIUM", "")
    low      = lookup(oci_database_autonomous_database.partition_test_db.connection_strings[0].all_connection_strings, "LOW", "")
    tp       = lookup(oci_database_autonomous_database.partition_test_db.connection_strings[0].all_connection_strings, "TP", "")
    tpurgent = lookup(oci_database_autonomous_database.partition_test_db.connection_strings[0].all_connection_strings, "TPURGENT", "")
  }
}

# Credentials (Sensitive)
output "admin_username" {
  description = "The admin username for the database"
  value       = "ADMIN"
}

output "admin_password" {
  description = "The admin password for the database"
  value       = var.admin_password != "" ? var.admin_password : random_password.admin_password[0].result
  sensitive   = true
}

# Wallet Information
output "wallet_download_url" {
  description = "URL to download the database wallet"
  value       = "https://console.${var.region}.oraclecloud.com/db/databases/${oci_database_autonomous_database.partition_test_db.id}/wallet"
}

output "wallet_content" {
  description = "Base64 encoded wallet content (if wallet was created)"
  value       = var.create_wallet ? oci_database_autonomous_database_wallet.partition_test_wallet[0].content : ""
  sensitive   = true
}

# Database Configuration
output "database_config" {
  description = "Database configuration details"
  value = {
    cpu_core_count           = oci_database_autonomous_database.partition_test_db.cpu_core_count
    data_storage_size_in_tbs = oci_database_autonomous_database.partition_test_db.data_storage_size_in_tbs
    auto_scaling_enabled     = oci_database_autonomous_database.partition_test_db.is_auto_scaling_enabled
    is_free_tier             = oci_database_autonomous_database.partition_test_db.is_free_tier
    license_model            = oci_database_autonomous_database.partition_test_db.license_model
  }
}

# Object Storage (if created)
output "storage_bucket_name" {
  description = "The name of the Object Storage bucket (if created)"
  value       = var.create_storage_bucket ? oci_objectstorage_bucket.partition_test_bucket[0].name : ""
}

output "storage_namespace" {
  description = "The Object Storage namespace"
  value       = var.create_storage_bucket ? data.oci_objectstorage_namespace.ns.namespace : ""
}

# Testing Information
output "sqlplus_connection_string" {
  description = "SQL*Plus connection string for testing"
  value       = "sqlplus admin/${var.admin_password != "" ? var.admin_password : random_password.admin_password[0].result}@${lookup(oci_database_autonomous_database.partition_test_db.connection_strings[0].all_connection_strings, "HIGH", "")}"
  sensitive   = true
}

# Environment Information
output "environment_info" {
  description = "Environment information and metadata"
  value = {
    environment_name = var.environment_name
    region           = var.region
    compartment_id   = var.compartment_ocid
    created_time     = oci_database_autonomous_database.partition_test_db.time_created
    tags             = oci_database_autonomous_database.partition_test_db.freeform_tags
  }
}

# Infrastructure Quick Start Guide
output "infrastructure_guide" {
  description = "Infrastructure connection guide"
  value       = <<-EOT
    # Infrastructure is ready. Use Ansible for application deployment:
    
    # 1. Download the database wallet:
    oci db autonomous-database generate-wallet --autonomous-database-id ${oci_database_autonomous_database.partition_test_db.id} --password [wallet-password] --file wallet.zip

    # 2. Extract wallet and set TNS_ADMIN:
    unzip wallet.zip -d ./wallet/
    export TNS_ADMIN=./wallet

    # 3. Connect to database:
    sqlplus admin/[password]@${var.db_name}_high

    # 4. Deploy application using Ansible:
    ansible-playbook playbooks/install-packages.yml
  EOT
}
