terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.50"
    }
    random = {
      source = "hashicorp/random"
    }
  }

  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"
    storage_account_name = "tfstatelocalledger"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }

  required_version = ">= 1.3"
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# Resource Group

resource "azurerm_resource_group" "main" {
  name     = "${var.app_name}-rg"
  location = var.location
}

# Storage Account (Blob storage and Function App)

resource "random_string" "storage" {
  length  = 8
  upper   = false
  numeric = true
  special = false
}

resource "azurerm_storage_account" "main" {
  name                     = "st${random_string.storage.result}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = var.location
  account_tier             = var.storage_account_tier
  account_replication_type = var.storage_account_replication
}

resource "azurerm_storage_container" "reports" {
  name                  = "reports"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}

# Cosmos DB (SQL API)

resource "azurerm_cosmosdb_account" "main" {
  name                = "${var.app_name}-cosmos"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"
  consistency_policy {
    consistency_level = var.cosmos_db_consistency_level
  }

  geo_location {
    location          = var.location
    failover_priority = 0
  }
}

resource "azurerm_cosmosdb_sql_database" "ledger" {
  name                = "ledger"
  resource_group_name = azurerm_resource_group.main.name
  account_name        = azurerm_cosmosdb_account.main.name
}

resource "azurerm_cosmosdb_sql_container" "transactions" {
  name                = "transactions"
  resource_group_name = azurerm_resource_group.main.name
  account_name        = azurerm_cosmosdb_account.main.name
  database_name       = azurerm_cosmosdb_sql_database.ledger.name
  partition_key_paths = ["/userId"]
  throughput          = 400
}

# Log Analytics Workspace

resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.app_name}-law"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_analytics_retention_days
}

# Application Insights

resource "azurerm_application_insights" "main" {
  name                = "${var.app_name}-appi"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.main.id
  sampling_percentage = var.app_insights_sampling_percentage
}

# Function App Service Plan

resource "azurerm_service_plan" "functions" {
  name                = "${var.app_name}-plan"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  os_type             = "Linux"
  sku_name            = var.function_app_sku
}

# Azure AD B2C

resource "azurerm_aadb2c_directory" "main" {
  count                   = var.enable_b2c ? 1 : 0
  country_code            = var.b2c_country_code
  data_residency_location = var.b2c_location
  display_name            = "${var.app_name}-b2c"
  domain_name             = "${var.app_name}auth.onmicrosoft.com"
  resource_group_name     = azurerm_resource_group.main.name
  sku_name                = var.b2c_sku
}

# Function App

resource "azurerm_linux_function_app" "backend" {
  name                       = "${var.app_name}-func"
  location                   = var.location
  resource_group_name        = azurerm_resource_group.main.name
  service_plan_id            = azurerm_service_plan.functions.id
  storage_account_name       = azurerm_storage_account.main.name
  storage_account_access_key = azurerm_storage_account.main.primary_access_key

  site_config {
    application_stack {
      node_version = var.node_version
    }
    cors {
      allowed_origins = ["*"]
    }
  }

  auth_settings_v2 {
    auth_enabled           = var.enable_auth
    require_authentication = var.enable_auth

    login {
      token_store_enabled = true
    }

    active_directory_v2 {
      client_id                  = coalesce(var.b2c_client_id, "dummy-client-id")
      tenant_auth_endpoint       = var.enable_auth && var.enable_b2c ? "https://${azurerm_aadb2c_directory.main[0].domain_name}/v2.0" : "https://dummy-endpoint"
      client_secret_setting_name = "MICROSOFT_PROVIDER_AUTHENTICATION_SECRET"
    }
  }

  app_settings = merge({
    "FUNCTIONS_WORKER_RUNTIME"              = var.function_app_runtime
    "APPINSIGHTS_INSTRUMENTATIONKEY"        = azurerm_application_insights.main.instrumentation_key
    "AzureWebJobsStorage"                   = azurerm_storage_account.main.primary_connection_string
    "COSMOSDB_CONNECTION_STRING"            = azurerm_cosmosdb_account.main.primary_sql_connection_string
    "COSMOSDB_DATABASE_NAME"                = azurerm_cosmosdb_sql_database.ledger.name
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.main.connection_string
    "AzureADB2C_Domain"                     = var.enable_b2c ? azurerm_aadb2c_directory.main[0].domain_name : ""
    "AzureADB2C_ClientId"                   = var.b2c_client_id
    "WEBSITE_NODE_DEFAULT_VERSION"          = var.node_version
  }, var.function_app_runtime_settings)
}

# first create the Static Web App
resource "azurerm_static_web_app" "frontend" {
  name                = "${var.app_name}-static"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  sku_tier            = var.static_web_app_sku
}

# then update the Function App CORS settings
resource "azurerm_app_service_custom_hostname_binding" "function_cors" {
  depends_on = [
    azurerm_static_web_app.frontend,
    azurerm_linux_function_app.backend
  ]

  hostname            = azurerm_static_web_app.frontend.default_host_name
  app_service_name    = azurerm_linux_function_app.backend.name
  resource_group_name = azurerm_resource_group.main.name
}

