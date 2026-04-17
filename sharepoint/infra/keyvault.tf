# ------------------------------------------------------------------------------
# Azure Key Vault (SharePoint credentials, Elasticsearch config, secrets)
# ------------------------------------------------------------------------------
resource "azurerm_key_vault" "main" {
  name                          = "kv-${local.resource_suffix}"
  resource_group_name           = azurerm_resource_group.main.name
  location                      = azurerm_resource_group.main.location
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  rbac_authorization_enabled    = true
  purge_protection_enabled      = true
  soft_delete_retention_days    = 7
  public_network_access_enabled = true

  tags = local.tags
}

# --- SharePoint secrets (auto-generated from Entra ID app registration) ---
resource "azurerm_key_vault_secret" "sharepoint_client_id" {
  name         = "sharepoint-client-id"
  value        = azuread_application.sharepoint_connector.client_id
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_role_assignment.deployer_kv_admin]
}

resource "azurerm_key_vault_secret" "sharepoint_client_secret" {
  name         = "sharepoint-client-secret"
  value        = azuread_application_password.sharepoint_connector.value
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_role_assignment.deployer_kv_admin]
}

# --- Elasticsearch secrets (stubbed – populated when available) ---
resource "azurerm_key_vault_secret" "elasticsearch_endpoint" {
  count        = var.elasticsearch_endpoint != "" ? 1 : 0
  name         = "elasticsearch-endpoint"
  value        = var.elasticsearch_endpoint
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_role_assignment.deployer_kv_admin]
}

resource "azurerm_key_vault_secret" "elasticsearch_api_key" {
  count        = var.elasticsearch_api_key != "" ? 1 : 0
  name         = "elasticsearch-api-key"
  value        = var.elasticsearch_api_key
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_role_assignment.deployer_kv_admin]
}
