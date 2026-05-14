# ------------------------------------------------------------------------------
# Storage Account (Blob data source + Function App backing store)
# ------------------------------------------------------------------------------
resource "azurerm_storage_account" "main" {
  name                          = local.storage_account_name
  resource_group_name           = azurerm_resource_group.main.name
  location                      = azurerm_resource_group.main.location
  account_tier                  = "Standard"
  account_replication_type      = "LRS"
  min_tls_version               = "TLS1_2"
  shared_access_key_enabled     = true
  default_to_oauth_authentication = true
  allow_nested_items_to_be_public = false

  identity {
    type = "SystemAssigned"
  }

  tags = local.tags
}

# Container for ingested documents (Blob data source for AI Search)
resource "azurerm_storage_container" "documents" {
  name                  = "documents"
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"
}

# Container for skillset knowledge-store projections
resource "azurerm_storage_container" "knowledge_store" {
  name                  = "knowledge-store"
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"
}

# Container that holds the Flex Consumption deployment package
resource "azurerm_storage_container" "function_releases" {
  name                  = "function-releases"
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"
}
