# ------------------------------------------------------------------------------
# Azure Function App – Flex Consumption (Python 3.13)
# ------------------------------------------------------------------------------
resource "azurerm_service_plan" "main" {
  name                = "asp-${local.resource_suffix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = "FC1"

  tags = local.tags
}

resource "azurerm_function_app_flex_consumption" "elastic_sync" {
  name                = "func-${local.resource_suffix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  service_plan_id     = azurerm_service_plan.main.id

  # Deployment package container (required for Flex)
  storage_container_type      = "blobContainer"
  storage_container_endpoint  = "${azurerm_storage_account.main.primary_blob_endpoint}${azurerm_storage_container.function_releases.name}"
  storage_authentication_type = "StorageAccountConnectionString"
  storage_access_key          = azurerm_storage_account.main.primary_access_key

  runtime_name           = "python"
  runtime_version        = "3.13"
  maximum_instance_count = 40
  instance_memory_in_mb  = 2048

  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_insights_connection_string = azurerm_application_insights.main.connection_string
  }

  app_settings = {
    # AI Search
    "AI_SEARCH_ENDPOINT"   = "https://${azurerm_search_service.main.name}.search.windows.net"
    "AI_SEARCH_INDEX_NAME" = var.search_index_name

    # AI Services (OpenAI models via Foundry)
    "AI_SERVICES_ENDPOINT" = azurerm_cognitive_account.ai_services.endpoint
    "EMBEDDING_DEPLOYMENT" = var.embedding_model_name

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
    function_app_hash = filemd5("${path.module}/../app/function_app/function_app.py")
    requirements_hash = filemd5("${path.module}/../app/function_app/requirements.txt")
    host_json_hash    = filemd5("${path.module}/../app/function_app/host.json")
  }

  provisioner "local-exec" {
    working_dir = "${path.module}/../app/function_app"
    interpreter = ["pwsh", "-Command"]
    command     = <<-CMD
      $appName = '${azurerm_function_app_flex_consumption.elastic_sync.name}'
      $scmUrl  = "https://$appName.scm.azurewebsites.net/api/settings"

      Write-Host "Waiting for SCM site ($scmUrl) to become available..."
      $maxAttempts = 30
      $ready = $false
      for ($i = 1; $i -le $maxAttempts; $i++) {
        try {
          $resp = Invoke-WebRequest -Uri $scmUrl -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop
          if ($resp.StatusCode -lt 500) {
            Write-Host "SCM site is responding (HTTP $($resp.StatusCode)) on attempt $i."
            $ready = $true
            break
          }
        } catch {
          Write-Host ("Attempt {0}/{1}: SCM site not ready yet ({2}). Sleeping 15s..." -f $i, $maxAttempts, $_.Exception.Message)
        }
        Start-Sleep -Seconds 15
      }
      if (-not $ready) {
        Write-Host "SCM site did not become ready in time; attempting publish anyway."
      } else {
        Start-Sleep -Seconds 20
      }

      $publishAttempts = 5
      for ($j = 1; $j -le $publishAttempts; $j++) {
        Write-Host ("Publishing function app (attempt {0}/{1})..." -f $j, $publishAttempts)
        func azure functionapp publish $appName --python
        if ($LASTEXITCODE -eq 0) {
          Write-Host "Publish succeeded."
          exit 0
        }
        Write-Host "Publish failed with exit $LASTEXITCODE. Sleeping 30s before retry..."
        Start-Sleep -Seconds 30
      }
      Write-Host "All publish attempts failed."
      exit 1
    CMD
  }
}
