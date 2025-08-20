resource "azurerm_databricks_workspace" "ws" {
  name                        = local.databricks_ws
  resource_group_name         = azurerm_resource_group.rg.name
  location                    = var.location
  sku                         = "standard"  
  managed_resource_group_name = "rg-${local.databricks_ws}"
}



# --------- Create spark cluster with OAuh pre set

# variable for datalake name for spark config
locals { sa = azurerm_storage_account.dl.name }


resource "databricks_cluster" "single_node_adls" {

  depends_on = [
    databricks_secret.client_id,
    databricks_secret.client_secret,
    databricks_secret.tenant_id,
    databricks_secret.aad_endpoint,
    azurerm_role_assignment.dbx_sp_storage_contrib
  ]

  cluster_name            = "adf-single-node-adls"
  spark_version           = "13.3.x-scala2.12"
  node_type_id            = "Standard_D4ds_v5" # choose a SKU you have quota for
  autotermination_minutes = 10
  num_workers             = 0
  custom_tags             = { ResourceClass = "SingleNode" }

  spark_conf = {
    "spark.databricks.cluster.profile"                                                   = "singleNode"
    "spark.master"                                                                       = "local[*]"
    "spark.hadoop.fs.azure.account.auth.type.${local.sa}.dfs.core.windows.net"           = "OAuth"
    "spark.hadoop.fs.azure.account.oauth.provider.type.${local.sa}.dfs.core.windows.net" = "org.apache.hadoop.fs.azurebfs.oauth2.ClientCredsTokenProvider"
    "spark.hadoop.fs.azure.account.oauth2.client.id.${local.sa}.dfs.core.windows.net"       = "{{secrets/${databricks_secret_scope.adls.name}/client-id}}"
    "spark.hadoop.fs.azure.account.oauth2.client.secret.${local.sa}.dfs.core.windows.net"   = "{{secrets/${databricks_secret_scope.adls.name}/client-secret}}"
    "spark.hadoop.fs.azure.account.oauth2.client.endpoint.${local.sa}.dfs.core.windows.net" = "{{secrets/${databricks_secret_scope.adls.name}/aad-endpoint}}"
  }
}