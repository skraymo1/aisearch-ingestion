# ------------------------------------------------------------------------------
# Managed Identity Role Assignments
# Principle: use Managed Identity for all connections when possible
# ------------------------------------------------------------------------------

# --- Deployer → Storage (required for terraform with storage_use_azuread) ---
resource "azurerm_role_assignment" "deployer_storage_blob_contributor" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

# --- Deployer → Key Vault (so Terraform can write secrets) ---
resource "azurerm_role_assignment" "deployer_kv_admin" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

# --- AI Search → Storage (read blob data source) ---
resource "azurerm_role_assignment" "search_storage_blob_reader" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_search_service.main.identity[0].principal_id
}

# --- AI Search → AI Services (embedding skill, Content Understanding, cognitive services) ---
resource "azurerm_role_assignment" "search_ai_services_user" {
  scope                = azurerm_cognitive_account.ai_services.id
  role_definition_name = "Cognitive Services User"
  principal_id         = azurerm_search_service.main.identity[0].principal_id
}

# --- Function App → AI Search (read index for Elasticsearch sync) ---
resource "azurerm_role_assignment" "func_search_reader" {
  scope                = azurerm_search_service.main.id
  role_definition_name = "Search Index Data Reader"
  principal_id         = azurerm_function_app_flex_consumption.elastic_sync.identity[0].principal_id
}

# --- Function App → Key Vault (read secrets) ---
resource "azurerm_role_assignment" "func_kv_secrets_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_function_app_flex_consumption.elastic_sync.identity[0].principal_id
}

# --- Function App → Storage (blob access for processing) ---
resource "azurerm_role_assignment" "func_storage_contributor" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_function_app_flex_consumption.elastic_sync.identity[0].principal_id
}

# --- Function App → Storage (queue access for Functions runtime) ---
resource "azurerm_role_assignment" "func_storage_queue_contributor" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Queue Data Contributor"
  principal_id         = azurerm_function_app_flex_consumption.elastic_sync.identity[0].principal_id
}

# --- Function App → Storage (table access for Functions runtime) ---
resource "azurerm_role_assignment" "func_storage_table_contributor" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Table Data Contributor"
  principal_id         = azurerm_function_app_flex_consumption.elastic_sync.identity[0].principal_id
}

# --- Function App → Storage (account-level for Functions runtime) ---
resource "azurerm_role_assignment" "func_storage_account_contributor" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Account Contributor"
  principal_id         = azurerm_function_app_flex_consumption.elastic_sync.identity[0].principal_id
}

# --- Function App → AI Services (call GPT for vision analysis) ---
resource "azurerm_role_assignment" "func_ai_services_user" {
  scope                = azurerm_cognitive_account.ai_services.id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = azurerm_function_app_flex_consumption.elastic_sync.identity[0].principal_id
}

# --- Deployer → AI Search (query index data) ---
resource "azurerm_role_assignment" "deployer_search_index_reader" {
  scope                = azurerm_search_service.main.id
  role_definition_name = "Search Index Data Reader"
  principal_id         = data.azurerm_client_config.current.object_id
}

# --- Deployer → Azure AI Developer (manage Foundry projects) ---
resource "azurerm_role_assignment" "deployer_ai_developer" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Azure AI Developer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# --- Deployer → Cognitive Services User (access models & endpoints) ---
resource "azurerm_role_assignment" "deployer_cognitive_services_user" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Cognitive Services User"
  principal_id         = data.azurerm_client_config.current.object_id
}

# --- Foundry Project Identity → Cognitive Services Contributor on AI Services ---
resource "azurerm_role_assignment" "foundry_project_cognitive_contributor" {
  scope                = azurerm_cognitive_account.ai_services.id
  role_definition_name = "Cognitive Services Contributor"
  principal_id         = azapi_resource.foundry_project.identity[0].principal_id
}

# --- Foundry Project Identity → Search Index Data Reader on AI Search ---
resource "azurerm_role_assignment" "foundry_project_search_reader" {
  scope                = azurerm_search_service.main.id
  role_definition_name = "Search Index Data Reader"
  principal_id         = azapi_resource.foundry_project.identity[0].principal_id
}

# --- Foundry Project Identity → Search Service Contributor on AI Search ---
resource "azurerm_role_assignment" "foundry_project_search_contributor" {
  scope                = azurerm_search_service.main.id
  role_definition_name = "Search Service Contributor"
  principal_id         = azapi_resource.foundry_project.identity[0].principal_id
}


