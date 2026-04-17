# ------------------------------------------------------------------------------
# AI Services (multi-service account for OpenAI models – Foundry portal)
# ------------------------------------------------------------------------------
resource "azurerm_cognitive_account" "ai_services" {
  name                = "ais-${local.resource_suffix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  kind                = "AIServices"
  sku_name            = "S0"

  custom_subdomain_name = "ais-${local.resource_suffix}"
  local_auth_enabled    = false
  project_management_enabled = true

  identity {
    type = "SystemAssigned"
  }

  tags = local.tags
}

# Embedding model deployment
resource "azurerm_cognitive_deployment" "embedding" {
  name                 = var.embedding_model_name
  cognitive_account_id = azurerm_cognitive_account.ai_services.id

  model {
    format  = "OpenAI"
    name    = var.embedding_model_name
    version = var.embedding_model_version
  }

  sku {
    name     = "GlobalStandard"
    capacity = var.embedding_model_capacity
  }

  rai_policy_name = "Microsoft.DefaultV2"
}

# ------------------------------------------------------------------------------
# AI Foundry Project
# ------------------------------------------------------------------------------
locals {
  foundry_project_name = var.foundry_project_name != "" ? var.foundry_project_name : "ai-project-${local.resource_suffix}"
}

resource "azapi_resource" "foundry_project" {
  type      = "Microsoft.CognitiveServices/accounts/projects@2025-06-01"
  name      = local.foundry_project_name
  parent_id = azurerm_cognitive_account.ai_services.id
  location  = azurerm_resource_group.main.location

  identity {
    type = "SystemAssigned"
  }

  body = {
    properties = {
      description = "${local.foundry_project_name} Project"
      displayName = "${local.foundry_project_name}"
    }
  }

  schema_validation_enabled = false
  response_export_values    = ["properties.endpoints", "identity.principalId"]

  depends_on = [
    azurerm_cognitive_deployment.embedding,
  ]
}

# ------------------------------------------------------------------------------
# Capability Host (for hosted agents – optional, preview)
# ------------------------------------------------------------------------------
resource "azapi_resource" "foundry_capability_host" {
  count = var.enable_hosted_agents ? 1 : 0

  type      = "Microsoft.CognitiveServices/accounts/capabilityHosts@2025-10-01-preview"
  name      = "agents"
  parent_id = azurerm_cognitive_account.ai_services.id

  body = {
    properties = {
      capabilityHostKind             = "Agents"
      enablePublicHostingEnvironment = true
    }
  }

  schema_validation_enabled = false

  depends_on = [azapi_resource.foundry_project]
}

# ------------------------------------------------------------------------------
# Connect existing Application Insights to the Foundry Project
# ------------------------------------------------------------------------------
resource "azapi_resource" "foundry_appinsights_connection" {
  type      = "Microsoft.CognitiveServices/accounts/projects/connections@2025-04-01-preview"
  name      = "appi-connection"
  parent_id = azapi_resource.foundry_project.id

  body = {
    properties = {
      category      = "AppInsights"
      target        = azurerm_application_insights.main.id
      authType      = "ApiKey"
      isSharedToAll = true
      credentials = {
        key = azurerm_application_insights.main.connection_string
      }
      metadata = {
        ApiType    = "Azure"
        ResourceId = azurerm_application_insights.main.id
      }
    }
  }

  schema_validation_enabled = false
}
