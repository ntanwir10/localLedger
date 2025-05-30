variable "location" {
  description = "Azure region to deploy resources in"
  type        = string
  default     = "eastus2"
}

variable "app_name" {
  description = "Base name for all resources"
  type        = string
  default     = "ledger"
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

variable "enable_auth" {
  description = "Enable authentication for the Function App"
  type        = bool
  default     = false
}

variable "entra_tenant_id" {
  description = "Microsoft Entra tenant ID"
  type        = string
  default     = ""
}

variable "entra_client_id" {
  description = "Microsoft Entra application (client) ID"
  type        = string
  default     = ""
}

variable "entra_client_secret" {
  description = "Microsoft Entra application client secret"
  type        = string
  sensitive   = true
  default     = ""
}

variable "entra_allowed_audiences" {
  description = "List of allowed token audiences for Microsoft Entra"
  type        = list(string)
  default     = []
}

variable "entra_issuer_url" {
  description = "Microsoft Entra token issuer URL"
  type        = string
  default     = ""
}
