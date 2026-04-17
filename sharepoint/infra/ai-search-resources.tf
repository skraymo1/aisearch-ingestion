# ------------------------------------------------------------------------------
# Deploy AI Search Data-Plane Resources (index, skillset, datasources, indexers)
#
# The azurerm/azapi providers do not support AI Search data-plane APIs.
# We use a null_resource provisioner to run deploy_search.py after all
# infrastructure is ready.
# ------------------------------------------------------------------------------

# Wait for Azure RBAC propagation (role assignments can take 1-5 min on fresh deploy)
resource "time_sleep" "wait_for_rbac" {
  depends_on = [
    azurerm_role_assignment.search_storage_blob_reader,
    azurerm_role_assignment.search_ai_services_user,
    azurerm_role_assignment.func_search_reader,
    azurerm_role_assignment.func_ai_services_user,
  ]
  create_duration = "60s"
}

resource "terraform_data" "deploy_search_resources" {
  depends_on = [
    azurerm_search_service.main,
    azurerm_cognitive_account.ai_services,
    azurerm_cognitive_deployment.embedding,
    azurerm_storage_account.main,
    azurerm_storage_container.documents,
    azurerm_linux_function_app.elastic_sync,
    azurerm_key_vault_secret.sharepoint_client_id,
    azurerm_key_vault_secret.sharepoint_client_secret,
    terraform_data.deploy_function_code,
    time_sleep.wait_for_rbac,
  ]

  # Re-run when JSON templates or deploy script change
  # NOTE: SharePoint datasource/indexer are handled by deploy_sharepoint_indexer below.
  triggers_replace = {
    index_hash           = filemd5("${path.module}/../app/search/index.json")
    skillset_hash        = filemd5("${path.module}/../app/search/skillset.json")
    datasource_blob_hash = filemd5("${path.module}/../app/search/datasource_blob.json")
    indexer_blob_hash    = filemd5("${path.module}/../app/search/indexer_blob.json")
    deploy_script_hash   = filemd5("${path.module}/../app/search/deploy_search.py")
  }

  provisioner "local-exec" {
    working_dir = "${path.module}/../app/search"
    interpreter = ["pwsh", "-Command"]
    command     = "$funcKey = (az functionapp function keys list --name '${azurerm_linux_function_app.elastic_sync.name}' --resource-group '${azurerm_resource_group.main.name}' --function-name 'ElasticSync' --query 'default' -o tsv); py deploy_search.py --search-endpoint 'https://${azurerm_search_service.main.name}.search.windows.net' --function-app-url 'https://${azurerm_linux_function_app.elastic_sync.default_hostname}' --function-host-key $funcKey --ai-services-endpoint '${azurerm_cognitive_account.ai_services.endpoint}' --subscription-id '${data.azurerm_client_config.current.subscription_id}' --resource-group '${azurerm_resource_group.main.name}' --storage-account-name '${azurerm_storage_account.main.name}'"
  }
}

# ------------------------------------------------------------------------------
# Deploy SharePoint Indexer & Data Source (dedicated resource)
#
# Runs separately from the main search deployment so the SharePoint indexer can
# be created/updated independently.
#
# To force re-creation: terraform apply -replace="terraform_data.deploy_sharepoint_indexer"
# ------------------------------------------------------------------------------

resource "terraform_data" "deploy_sharepoint_indexer" {
  depends_on = [
    terraform_data.deploy_search_resources,
    terraform_data.deploy_function_code,
    azuread_application_password.sharepoint_connector,
    azuread_app_role_assignment.files_read_all,
    azuread_app_role_assignment.sites_read_all,
    azurerm_cognitive_deployment.embedding,
    time_sleep.wait_for_rbac,
  ]

  triggers_replace = {
    datasource_sp_hash   = filemd5("${path.module}/../app/search/datasource_sharepoint.json")
    indexer_sp_hash      = filemd5("${path.module}/../app/search/indexer_sharepoint.json")
    sharepoint_site_url  = var.sharepoint_site_url
    sharepoint_client_id = azuread_application.sharepoint_connector.client_id
  }

  provisioner "local-exec" {
    working_dir = "${path.module}/../app/search"
    interpreter = ["pwsh", "-Command"]
    command     = "$funcKey = (az functionapp function keys list --name '${azurerm_linux_function_app.elastic_sync.name}' --resource-group '${azurerm_resource_group.main.name}' --function-name 'ElasticSync' --query 'default' -o tsv); py deploy_search.py --search-endpoint 'https://${azurerm_search_service.main.name}.search.windows.net' --function-app-url 'https://${azurerm_linux_function_app.elastic_sync.default_hostname}' --function-host-key $funcKey --ai-services-endpoint '${azurerm_cognitive_account.ai_services.endpoint}' --only index skillset datasources indexers --sharepoint-site-url '${var.sharepoint_site_url}' --sharepoint-tenant-id '${data.azurerm_client_config.current.tenant_id}' --sharepoint-client-id '${azuread_application.sharepoint_connector.client_id}' --sharepoint-client-secret '${azuread_application_password.sharepoint_connector.value}' --subscription-id '${data.azurerm_client_config.current.subscription_id}' --resource-group '${azurerm_resource_group.main.name}' --storage-account-name '${azurerm_storage_account.main.name}'"
  }
}
