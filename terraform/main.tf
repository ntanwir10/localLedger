terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.50"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.47.0"
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

provider "azuread" {
  # Configuration will use environment variables:
  # ARM_TENANT_ID, ARM_CLIENT_ID, ARM_CLIENT_SECRET
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
  name                = "${lower(replace(var.app_name, "_", "-"))}-cosmos-${random_string.storage.result}"
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

# Microsoft Entra External ID Configuration
resource "azuread_application" "main" {
  count        = var.enable_auth ? 1 : 0
  display_name = "${var.app_name}-app"

  # Sign in audience configuration
  sign_in_audience = "AzureADandPersonalMicrosoftAccount" # Allows both work/school and personal accounts

  web {
    homepage_url = "https://${azurerm_static_web_app.frontend.default_host_name}"
    redirect_uris = [
      "https://${azurerm_static_web_app.frontend.default_host_name}/signin-oidc",
      "https://${azurerm_static_web_app.frontend.default_host_name}/silent-refresh"
    ]
    logout_url = "https://${azurerm_static_web_app.frontend.default_host_name}/signout-oidc"

    implicit_grant {
      access_token_issuance_enabled = true
      id_token_issuance_enabled     = true
    }
  }

  # API permissions and scopes
  api {
    requested_access_token_version = 2
    oauth2_permission_scope {
      admin_consent_description  = "Allow the application to access ${var.app_name} on behalf of the signed-in user."
      admin_consent_display_name = "Access ${var.app_name}"
      enabled                    = true
      id                         = "96183846-204b-4b43-82e1-5d2222eb4b9a"
      type                       = "User"
      user_consent_description   = "Allow the application to access ${var.app_name} on your behalf."
      user_consent_display_name  = "Access ${var.app_name}"
      value                      = "user_impersonation"
    }
  }

  # Required Microsoft Graph permissions
  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000" # Microsoft Graph

    resource_access {
      id   = "e1fe6dd8-ba31-4d61-89e7-88639da4683d" # User.Read
      type = "Scope"
    }

    resource_access {
      id   = "37f7f235-527c-4136-accd-4a02d197296e" # openid
      type = "Scope"
    }

    resource_access {
      id   = "7427e0e9-2fba-42fe-b0c0-848c9e6a8182" # offline_access
      type = "Scope"
    }

    resource_access {
      id   = "14dad69e-099b-42c9-810b-d002981feec1" # profile
      type = "Scope"
    }
  }

  # Optional features for enhanced security
  optional_claims {
    access_token {
      name = "groups"
    }
    id_token {
      name = "groups"
    }
  }

  feature_tags {
    enterprise = true
    gallery    = false
  }
}

# Application credentials
resource "azuread_application_password" "main" {
  count          = var.enable_auth ? 1 : 0
  display_name   = "terraform-managed"
  end_date       = timeadd(timestamp(), "8760h")
  application_id = azuread_application.main[0].id
}

# Service principal
resource "azuread_service_principal" "main" {
  count        = var.enable_auth ? 1 : 0
  client_id    = azuread_application.main[0].client_id
  use_existing = true

  feature_tags {
    enterprise = true
    gallery    = false
  }

  # Add app roles if needed
  app_role_assignment_required = false
}

# Function App with Entra ID auth
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
      allowed_origins = ["https://${azurerm_static_web_app.frontend.default_host_name}"]
    }
  }

  auth_settings_v2 {
    auth_enabled           = var.enable_auth
    require_authentication = var.enable_auth

    login {
      token_store_enabled = true
    }

    active_directory_v2 {
      client_id                   = var.enable_auth ? azuread_application.main[0].client_id : "dummy-client-id"
      tenant_auth_endpoint        = var.enable_auth ? "https://login.microsoftonline.com/${var.entra_tenant_id}/v2.0" : "https://dummy-endpoint"
      client_secret_setting_name  = "MICROSOFT_PROVIDER_AUTHENTICATION_SECRET"
      allowed_audiences           = var.enable_auth ? concat([azuread_application.main[0].client_id], var.entra_allowed_audiences) : []
      allowed_applications        = var.enable_auth ? concat([azuread_application.main[0].client_id], var.entra_allowed_audiences) : []
      www_authentication_disabled = false
    }
  }

  app_settings = merge({
    "FUNCTIONS_WORKER_RUNTIME"                    = var.function_app_runtime
    "APPINSIGHTS_INSTRUMENTATIONKEY"              = azurerm_application_insights.main.instrumentation_key
    "AzureWebJobsStorage"                         = azurerm_storage_account.main.primary_connection_string
    "COSMOSDB_CONNECTION_STRING"                  = azurerm_cosmosdb_account.main.primary_sql_connection_string
    "COSMOSDB_DATABASE_NAME"                      = azurerm_cosmosdb_sql_database.ledger.name
    "APPLICATIONINSIGHTS_CONNECTION_STRING"       = azurerm_application_insights.main.connection_string
    "WEBSITE_NODE_DEFAULT_VERSION"                = var.node_version
    "MICROSOFT_PROVIDER_AUTHENTICATION_SECRET"    = var.enable_auth ? azuread_application_password.main[0].value : ""
    "MICROSOFT_PROVIDER_AUTHENTICATION_ISSUER"    = var.enable_auth ? "https://login.microsoftonline.com/${var.entra_tenant_id}/v2.0" : ""
    "MICROSOFT_PROVIDER_AUTHENTICATION_CLIENT_ID" = var.enable_auth ? azuread_application.main[0].client_id : ""
    "MICROSOFT_PROVIDER_AUTHENTICATION_AUDIENCE"  = var.enable_auth ? azuread_application.main[0].client_id : ""
    "MICROSOFT_PROVIDER_AUTHENTICATION_TENANT_ID" = var.enable_auth ? var.entra_tenant_id : ""
  }, var.function_app_runtime_settings)
}

# first create the Static Web App
resource "azurerm_static_web_app" "frontend" {
  name                = "${var.app_name}-static"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  sku_tier            = var.static_web_app_sku
}

# CORS is configured directly in the Function App site_config

