resource "azurerm_storage_account" "dl" {
  name                     = local.storage_account          
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = var.location
  account_kind             = "StorageV2"
  account_tier             = "Standard"                     
  account_replication_type = "LRS"
  is_hns_enabled           = true
  min_tls_version          = "TLS1_2"                       
}

resource "azurerm_storage_data_lake_gen2_filesystem" "containers" {
  for_each           = toset(["bronze", "silver", "gold"])
  name               = each.value
  storage_account_id = azurerm_storage_account.dl.id
}