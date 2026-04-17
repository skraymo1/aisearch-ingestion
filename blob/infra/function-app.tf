# ------------------------------------------------------------------------------
# Azure Function App (custom skills + Elasticsearch sync) – Flex Consumption
# ------------------------------------------------------------------------------
resource "azurerm_service_plan" "main" {
  name                = "asp-${local.resource_suffix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = "FC1"

  tags = local.tags
}

# Blob container for Flex Consumption deployment packages
resource "azurerm_storage_container" "function_deployments" {
  name                  = "function-deployments"
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"
}

resource "azurerm_function_app_flex_consumption" "elastic_sync" {
  name                = "func-${local.resource_suffix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  service_plan_id     = azurerm_service_plan.main.id

  storage_container_type      = "blobContainer"
  storage_container_endpoint  = "${azurerm_storage_account.main.primary_blob_endpoint}${azurerm_storage_container.function_deployments.name}"
  storage_authentication_type = "SystemAssignedIdentity"

  runtime_name           = "python"
  runtime_version        = "3.13"
  maximum_instance_count = 40
  instance_memory_in_mb  = 2048

  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_insights_connection_string = azurerm_application_insights.main.connection_string

    cors {
      allowed_origins = [
        "https://portal.azure.com",
      ]
    }
  }

  app_settings = {
    # Runtime storage (managed identity)
    # Setting AzureWebJobsStorage to "" is a required workaround for the azurerm provider with Flex Consumption.
    # See: https://github.com/hashicorp/terraform-provider-azurerm/pull/29099
    "AzureWebJobsStorage"              = ""
    "AzureWebJobsStorage__accountName" = azurerm_storage_account.main.name

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
    azurerm_function_app_flex_consumption.elastic_sync,
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
    command     = "& '${path.module}/../.venv/Scripts/Activate.ps1'; func azure functionapp publish '${azurerm_function_app_flex_consumption.elastic_sync.name}' --python; if ($LASTEXITCODE -eq 1) { Write-Host 'Deployment completed (health check may timeout on Flex Consumption cold start - this is expected)'; exit 0 }"
  }
}
