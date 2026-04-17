# ------------------------------------------------------------------------------
# Entra ID App Registration for SharePoint Indexer (Application Permissions)
# Uses Files.Read.All + Sites.Read.All for standard content indexing:
# https://learn.microsoft.com/azure/search/search-how-to-index-sharepoint-online
# ------------------------------------------------------------------------------

data "azuread_client_config" "current" {}

# Well-known Microsoft Graph Application ID
locals {
  microsoft_graph_app_id = "00000003-0000-0000-c000-000000000000"
}

resource "azuread_application" "sharepoint_connector" {
  display_name = "${var.project_name}-sharepoint-connector"
  owners       = [data.azuread_client_config.current.object_id]

  required_resource_access {
    resource_app_id = local.microsoft_graph_app_id

    resource_access {
      id   = data.azuread_service_principal.microsoft_graph.app_role_ids["Files.Read.All"]
      type = "Role"
    }

    resource_access {
      id   = data.azuread_service_principal.microsoft_graph.app_role_ids["Sites.Read.All"]
      type = "Role"
    }
  }
}

resource "azuread_service_principal" "sharepoint_connector" {
  client_id = azuread_application.sharepoint_connector.client_id
  owners    = [data.azuread_client_config.current.object_id]
}

resource "azuread_application_password" "sharepoint_connector" {
  application_id = azuread_application.sharepoint_connector.id
  display_name   = "terraform-managed"
  end_date       = timeadd(timestamp(), "8760h") # 1 year

  lifecycle {
    ignore_changes = [end_date]
  }
}

# Admin consent: grant Application Role assignments on Microsoft Graph
data "azuread_service_principal" "microsoft_graph" {
  client_id = local.microsoft_graph_app_id
}

resource "azuread_app_role_assignment" "files_read_all" {
  app_role_id         = data.azuread_service_principal.microsoft_graph.app_role_ids["Files.Read.All"]
  principal_object_id = azuread_service_principal.sharepoint_connector.object_id
  resource_object_id  = data.azuread_service_principal.microsoft_graph.object_id
}

resource "azuread_app_role_assignment" "sites_read_all" {
  app_role_id         = data.azuread_service_principal.microsoft_graph.app_role_ids["Sites.Read.All"]
  principal_object_id = azuread_service_principal.sharepoint_connector.object_id
  resource_object_id  = data.azuread_service_principal.microsoft_graph.object_id
}
