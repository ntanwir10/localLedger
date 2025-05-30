output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "static_web_app_url" {
  description = "The URL of the static web app"
  value       = azurerm_static_web_app.frontend.default_host_name
}

output "function_app_url" {
  value = azurerm_linux_function_app.backend.default_hostname
}

output "cosmos_db_account" {
  value = azurerm_cosmosdb_account.main.name
}

output "blob_storage_account" {
  value = azurerm_storage_account.main.name
}
