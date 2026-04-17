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
    azurerm_function_app_flex_consumption.elastic_sync,
    terraform_data.deploy_function_code,
    time_sleep.wait_for_rbac,
  ]

  # Re-run when JSON templates or deploy script change
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
    command     = "$hostKey = (az functionapp keys list --name '${azurerm_function_app_flex_consumption.elastic_sync.name}' --resource-group '${azurerm_resource_group.main.name}' --query 'functionKeys.default' -o tsv); py deploy_search.py --search-endpoint 'https://${azurerm_search_service.main.name}.search.windows.net' --function-app-url 'https://${azurerm_function_app_flex_consumption.elastic_sync.default_hostname}' --function-host-key $hostKey --ai-services-endpoint '${azurerm_cognitive_account.ai_services.endpoint}' --subscription-id '${data.azurerm_client_config.current.subscription_id}' --resource-group '${azurerm_resource_group.main.name}' --storage-account-name '${azurerm_storage_account.main.name}'"
  }
}
