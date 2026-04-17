output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "ai_search_name" {
  value = azurerm_search_service.main.name
}

output "ai_search_endpoint" {
  value = "https://${azurerm_search_service.main.name}.search.windows.net"
}

output "ai_services_endpoint" {
  value = azurerm_cognitive_account.ai_services.endpoint
}

output "ai_services_name" {
  value = azurerm_cognitive_account.ai_services.name
}

output "storage_account_name" {
  value = azurerm_storage_account.main.name
}

output "key_vault_uri" {
  value = azurerm_key_vault.main.vault_uri
}

output "function_app_name" {
  value = azurerm_function_app_flex_consumption.elastic_sync.name
}

output "function_app_url" {
  value = "https://${azurerm_function_app_flex_consumption.elastic_sync.default_hostname}"
}

output "function_app_custom_skill_url" {
  value = "https://${azurerm_function_app_flex_consumption.elastic_sync.default_hostname}/api/skills"
}

output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.main.id
}

output "app_insights_connection_string" {
  value     = azurerm_application_insights.main.connection_string
  sensitive = true
}

output "ai_services_id" {
  value       = azurerm_cognitive_account.ai_services.id
  description = "AI Services resource ID — this is the Foundry resource"
}

# ------------------------------------------------------------------------------
# AI Foundry Project
# ------------------------------------------------------------------------------
output "foundry_project_name" {
  value       = azapi_resource.foundry_project.name
  description = "AI Foundry project name"
}

output "foundry_project_id" {
  value       = azapi_resource.foundry_project.id
  description = "AI Foundry project resource ID"
}

output "foundry_project_endpoint" {
  value       = azapi_resource.foundry_project.output.properties.endpoints["AI Foundry API"]
  description = "AI Foundry project endpoint"
}

output "foundry_openai_endpoint" {
  value       = azurerm_cognitive_account.ai_services.endpoint
  description = "OpenAI endpoint via the AI Services account"
}


