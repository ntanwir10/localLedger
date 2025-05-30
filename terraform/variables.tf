variable "location" {
  description = "Azure region to deploy resources in"
  type        = string
  default     = "East US"
}

variable "app_name" {
  description = "Base name for all resources"
  type        = string
  default     = "localledger"
}

variable "b2c_location" {
  description = "Azure AD B2C tenant location"
  type        = string
  default     = "United States"
}

variable "b2c_country_code" {
  description = "Country code for B2C tenant"
  type        = string
  default     = "US"
}

variable "b2c_sku" {
  description = "SKU for Azure AD B2C"
  type        = string
  default     = "PremiumP1"
}

variable "cosmos_db_consistency_level" {
  description = "The consistency level of the Cosmos DB account"
  type        = string
  default     = "Session"
}

variable "storage_account_tier" {
  description = "Storage account tier (Standard or Premium)"
  type        = string
  default     = "Standard"
}

variable "storage_account_replication" {
  description = "Storage account replication type"
  type        = string
  default     = "LRS"
}

variable "function_app_sku" {
  description = "SKU for Function App service plan"
  type        = string
  default     = "Y1" # Consumption plan
}

variable "static_web_app_sku" {
  description = "SKU for Static Web App"
  type        = string
  default     = "Free"
}

variable "log_analytics_retention_days" {
  description = "Number of days to retain logs in Log Analytics"
  type        = number
  default     = 30
}

variable "app_insights_sampling_percentage" {
  description = "Sampling percentage for Application Insights"
  type        = number
  default     = 100
}

variable "node_version" {
  description = "Node.js version for Function App"
  type        = string
  default     = "20"
}

variable "function_app_runtime" {
  description = "The runtime stack for the Function App (node, python, java, powershell, dotnet)"
  type        = string
  default     = "node"
}

variable "function_app_version" {
  description = "The version of the runtime stack"
  type        = string
  default     = "20"
}

variable "function_app_runtime_settings" {
  description = "Additional runtime-specific settings"
  type        = map(string)
  default     = {}
}

variable "b2c_client_id" {
  description = "The client ID for Azure AD B2C authentication"
  type        = string
}

variable "enable_auth" {
  description = "Enable authentication for the Function App"
  type        = bool
  default     = false
}

variable "enable_b2c" {
  description = "Enable creation of Azure AD B2C tenant"
  type        = bool
  default     = false
}
