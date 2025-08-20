# access configurations


# ---------------------- SQL SERVER ----------------------

# Firewall - Allow Azure service to reach server
resource "azurerm_mssql_firewall_rule" "allow_azure" {
  name       = "allow-azure"
  server_id  = azurerm_mssql_server.sql.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# Firewall - temporary public access for access from personal ip. Should change for serious projects
resource "azurerm_mssql_firewall_rule" "temp_open" {
  name       = "temp-open"
  server_id  = azurerm_mssql_server.sql.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "255.255.255.255"
}

# ---------------------- Azure RBAC  ----------------------

# ADF MI -> ADLS Storage RBAC
resource "time_sleep" "wait_mi" {
  depends_on      = [azurerm_data_factory.adf]
  create_duration = "30s" 
}

resource "azurerm_role_assignment" "adf_storage_contrib" {
  depends_on = [time_sleep.wait_mi]
  scope                = azurerm_storage_account.dl.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_data_factory.adf.identity[0].principal_id
}

# ---------------------- Databricks access ----------------------


# ------- Databricks - ADF -----

# Look up ADF’s managed identity in Entra ID (Azure AD)
data "azuread_service_principal" "adf_mi" {
  object_id = azurerm_data_factory.adf.identity[0].principal_id
}

# Register ADF's MI inside the Databricks workspace. Databricks creates its own ID referenced by .id
resource "databricks_service_principal" "registered_adf_mi" {
  application_id = data.azuread_service_principal.adf_mi.client_id
  display_name   = "adf-${var.project}-${var.env}"
  active         = true
}

# Give the id generated above (service principal) "workspace access" access
resource "databricks_entitlements" "adf_mi_workspace_access" {
  service_principal_id = databricks_service_principal.registered_adf_mi.id
  workspace_access     = true
  # can add more later: databricks_sql_access = true, allow_cluster_create = true, etc.
}

# Create a shared folder for ADF notebooks exists
resource "databricks_directory" "adf_jobs" {
  path = "/Shared/adf_jobs"
}



# ------- Databricks - ADLS -----

# (1) App Registration in Azure AD (now Entra ID). This is a generic app registration with given display name. 
#     - application_id == client_id used by OAuth flows
#     - object_id is the directory object id of this app (used for secret creation)

resource "azuread_application" "dbx_to_adls_app" {
  display_name = "dbx-to-adls-${var.project}-${var.env}"
}

# (2) Create service principal for the app in *this tenant*
#     RBAC will be assigned to the service principal
resource "azuread_service_principal" "dbx_to_adls_sp" {
  client_id = azuread_application.dbx_to_adls_app.application_id
}

# (3) Create client secret for the app
#     Use application_object_id (not application_id) 
resource "azuread_application_password" "dbx_to_adls_secret" {
  application_object_id = azuread_application.dbx_to_adls_app.object_id
  display_name          = "dbx-to-adls-${var.project}-${var.env}"
  end_date_relative     = "8760h" # ≈ 1 year
}

# (4) Create RBAC using service principal. Allow the SP to read/write blobs in ADLS
resource "azurerm_role_assignment" "dbx_sp_storage_contrib" {
  scope                            = azurerm_storage_account.dl.id
  role_definition_name             = "Storage Blob Data Contributor"
  principal_id                     = azuread_service_principal.dbx_to_adls_sp.object_id
  skip_service_principal_aad_check = true  # avoids AAD eventual-consistency errors right after SP creation
}


# ------ Secrets in workspace. Will be used in databricks cluster creation ---

resource "databricks_secret_scope" "adls" {
  name                     = "adls-creds"
  initial_manage_principal = "users"   # Required on non-Premium
}

resource "databricks_secret" "tenant_id" {
  scope        = databricks_secret_scope.adls.name
  key          = "tenant-id"
  string_value = data.azurerm_client_config.current.tenant_id
}

resource "databricks_secret" "client_id" {
  scope        = databricks_secret_scope.adls.name
  key          = "client-id"
  string_value = azuread_application.dbx_to_adls_app.client_id
}

resource "databricks_secret" "client_secret" {
  scope        = databricks_secret_scope.adls.name
  key          = "client-secret"
  string_value = azuread_application_password.dbx_to_adls_secret.value
  # avoid perpetual diffs (value only known at create time)
  lifecycle { ignore_changes = [string_value] }
}

resource "databricks_secret" "aad_endpoint" {
  scope        = databricks_secret_scope.adls.name
  key          = "aad-endpoint"
  string_value = "https://login.microsoftonline.com/${data.azurerm_client_config.current.tenant_id}/oauth2/token"
}