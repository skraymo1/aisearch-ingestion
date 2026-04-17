# ------------------------------------------------------------------------------
# Azure Function App (custom skills + Elasticsearch sync)
# ------------------------------------------------------------------------------
resource "azurerm_service_plan" "main" {
  name                = "asp-${local.resource_suffix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = "Y1"

  tags = local.tags
}

resource "azurerm_linux_function_app" "elastic_sync" {
  name                          = "func-${local.resource_suffix}"
  resource_group_name           = azurerm_resource_group.main.name
  location                      = azurerm_resource_group.main.location
  service_plan_id               = azurerm_service_plan.main.id
  storage_account_name          = azurerm_storage_account.main.name
  storage_uses_managed_identity = true

  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false

  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_stack {
      python_version = "3.13"
    }
    application_insights_connection_string = azurerm_application_insights.main.connection_string
  }

  app_settings = {
    # AI Search
    "AI_SEARCH_ENDPOINT"    = "https://${azurerm_search_service.main.name}.search.windows.net"
    "AI_SEARCH_INDEX_NAME"  = var.search_index_name

    # AI Services (OpenAI models via Foundry)
    "AI_SERVICES_ENDPOINT"    = azurerm_cognitive_account.ai_services.endpoint
    "EMBEDDING_DEPLOYMENT"    = var.embedding_model_name

    # Elasticsearch (configurable – stubbed until available)
    "ELASTICSEARCH_ENDPOINT"   = var.elasticsearch_endpoint
    "ELASTICSEARCH_INDEX_NAME" = var.elasticsearch_index_name

    # Key Vault
    "KEY_VAULT_URI" = azurerm_key_vault.main.vault_uri

    # Managed identity for storage (required for Consumption plan)
    "AzureWebJobsStorage__accountName" = azurerm_storage_account.main.name
  }

  tags = local.tags
}

# ------------------------------------------------------------------------------
# Deploy Function App Code
# Uses Azure Functions Core Tools (func) to publish the Python code.
# Runs after the Function App infrastructure and RBAC assignments are ready.
# ------------------------------------------------------------------------------
resource "terraform_data" "deploy_function_code" {
  depends_on = [
    azurerm_linux_function_app.elastic_sync,
    azurerm_role_assignment.func_storage_contributor,
    azurerm_role_assignment.func_storage_queue_contributor,
    azurerm_role_assignment.func_storage_table_contributor,
    azurerm_role_assignment.func_storage_account_contributor,
    azurerm_role_assignment.func_kv_secrets_user,
    azurerm_role_assignment.func_search_reader,
    azurerm_role_assignment.func_ai_services_user,
    time_sleep.wait_for_rbac,
  ]

  triggers_replace = {
    function_app_hash  = filemd5("${path.module}/../app/function_app/function_app.py")
    requirements_hash  = filemd5("${path.module}/../app/function_app/requirements.txt")
    host_json_hash     = filemd5("${path.module}/../app/function_app/host.json")
  }

  provisioner "local-exec" {
    working_dir = "${path.module}/../app/function_app"
    interpreter = ["pwsh", "-Command"]
    command     = "func azure functionapp publish '${azurerm_linux_function_app.elastic_sync.name}' --python --build local"
  }
}
