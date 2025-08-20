# SQL Server 
# Register to AAD Admin (now microsoft entra id. Allows central management of manage identity and access to sql database )
resource "azurerm_mssql_server" "sql" {
  name                = local.sql_server
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  version             = "12.0"

   azuread_administrator {
    login_username              = data.azuread_user.me.user_principal_name
    object_id                   = data.azuread_user.me.object_id
    tenant_id                   = data.azurerm_client_config.current.tenant_id
    azuread_authentication_only = true
  }
}

# SQL Database
resource "azurerm_mssql_database" "db" {
  name      = local.sql_database
  server_id = azurerm_mssql_server.sql.id
  sku_name  = "GP_Gen5_2"     # Provisioned

  max_size_gb = 32
}