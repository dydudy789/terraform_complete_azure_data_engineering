resource "azurerm_data_factory" "adf" {
  name                = local.data_factory # use name created in main.tf
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  identity { type = "SystemAssigned" }
}


# ---------- ADF Linked Services ----------

# ADLS - managed identity for access
resource "azurerm_data_factory_linked_service_data_lake_storage_gen2" "ls_adls" {
  name                 = "ls-adls"
  data_factory_id      = azurerm_data_factory.adf.id
  url                  = "https://${azurerm_storage_account.dl.name}.dfs.core.windows.net"
  use_managed_identity = true
}

# Azure SQL DB - managed identity for access
resource "azurerm_data_factory_linked_service_azure_sql_database" "ls_sql" {
  name            = "ls-sqldb"
  data_factory_id = azurerm_data_factory.adf.id

  # Note the Authentication:
  connection_string = "Server=tcp:${azurerm_mssql_server.sql.fully_qualified_domain_name},1433;Database=${azurerm_mssql_database.db.name};Encrypt=True;Connection Timeout=30;Authentication=ActiveDirectoryMSI"
}

# Databricks (ADF will implicitly authenticate to the workspace using MSI (managed service identity, now managed identity))
resource "azurerm_data_factory_linked_service_azure_databricks" "ls_adb" {
  name                       = "ls-adb"
  data_factory_id            = azurerm_data_factory.adf.id
  adb_domain                 = "https://${azurerm_databricks_workspace.ws.workspace_url}"
  msi_work_space_resource_id = azurerm_databricks_workspace.ws.id

  # Use existing cluster for all activities that use this LS:
  existing_cluster_id = databricks_cluster.single_node_adls.id
}


# ---------- RBAC is defined in access_configs.tf ----------