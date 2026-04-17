# ------------------------------------------------------------------------------
# Azure AI Search
# ------------------------------------------------------------------------------
resource "azurerm_search_service" "main" {
  name                          = "srch-${local.resource_suffix}"
  resource_group_name           = azurerm_resource_group.main.name
  location                      = azurerm_resource_group.main.location
  sku                           = var.ai_search_sku
  semantic_search_sku           = "standard"
  local_authentication_enabled  = true
  authentication_failure_mode   = "http401WithBearerChallenge"

  identity {
    type = "SystemAssigned"
  }

  tags = local.tags
}
