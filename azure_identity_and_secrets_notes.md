

> **Note:** Unity Catalog + Access Connector require **Databricks Premium (or higher)**.

```text
Microsoft Entra ID (Azure AD)
|
├─ App Registration  → the app’s login name (client_id)
|   ├─ application_id (client_id) – use when the app signs in with a secret/cert, or when registering it in Databricks
|   |     e.g. Databricks SCIM registration:
|   |         application_id = data.azuread_service_principal.adf_mi.application_id
|   |     (or if you created your own app)
|   |         application_id = azuread_application.dbx_to_adls_app.application_id
|   └─ object_id – the “row ID” of this app in Entra; used when creating a client-secret
|         e.g. create a secret:
|             resource "azuread_application_password" "dbx_to_adls_secret" {
|               application_object_id = azuread_application.dbx_to_adls_app.object_id
|               display_name          = "client-secret"
|               end_date_relative     = "8760h"
|             }
|
└─ Service Principal  → the app’s account in your tenant (used for Azure RBAC)
    ├─ object_id – paste into Azure RBAC role assignments (who gets access)
    |     e.g. grant ADLS access:
    |         resource "azurerm_role_assignment" "adls_blob_contributor_for_dbx_sp" {
    |           scope                = azurerm_storage_account.dl.id
    |           role_definition_name = "Storage Blob Data Contributor"
    |           principal_id         = azuread_service_principal.dbx_to_adls_sp.object_id
    |           skip_service_principal_aad_check = true
    |         }
    └─ application_id (client_id) – points back to the App Registration (same “username”)

Azure resources
|
├─ ADF (system-assigned Managed Identity)
|   ├─ principal_id – the built-in account for ADF (internally an SP id)
|   |     e.g. ADF → ADLS (no secrets; just RBAC):
|   |         resource "azurerm_role_assignment" "adf_storage_contrib" {
|   |           scope                = azurerm_storage_account.dl.id
|   |           role_definition_name = "Storage Blob Data Contributor"
|   |           principal_id         = azurerm_data_factory.adf.identity[0].principal_id
|   |         }
|   └─ (optional) look up ADF’s identity as a Service Principal to get its application_id:
|         data "azuread_service_principal" "adf_mi" {
|           object_id = azurerm_data_factory.adf.identity[0].principal_id
|         }
|
└─ ADLS storage account
    └─ id – the Azure resource path; use as the role assignment scope
          e.g. scope = azurerm_storage_account.dl.id

Databricks workspace
|
├─ Databricks Service Principal (SCIM record)
|   ├─ id (Databricks-internal) – use for Databricks entitlements/grants
|   |     e.g. register ADF MI in Databricks:
|   |         resource "databricks_service_principal" "registered_adf_mi" {
|   |           application_id = data.azuread_service_principal.adf_mi.application_id
|   |           display_name   = "adf-${var.project}-${var.env}"
|   |           active         = true
|   |         }
|   |     e.g. grant workspace access in Databricks:
|   |         resource "databricks_entitlements" "adf_mi_workspace_access" {
|   |           service_principal_id = databricks_service_principal.registered_adf_mi.id
|   |           workspace_access     = true
|   |         }
|   └─ (UC, no secrets) Access Connector Managed Identity:
|         resource "azurerm_databricks_access_connector" "uc" {
|           name                = "ac-${var.project}-${var.env}"
|           resource_group_name = azurerm_resource_group.rg.name
|           location            = var.location
|           identity { type = "SystemAssigned" }
|         }
|         resource "azurerm_role_assignment" "uc_to_adls" {
|           scope                = azurerm_storage_account.dl.id
|           role_definition_name = "Storage Blob Data Contributor"
|           principal_id         = azurerm_databricks_access_connector.uc.identity[0].principal_id
|         }
|         resource "databricks_storage_credential" "adls" {
|           name = "cred-adls"
|           azure_managed_identity { access_connector_id = azurerm_databricks_access_connector.uc.id }
|         }
|         resource "databricks_external_location" "raw" {
|           name            = "loc-raw"
|           url             = "abfss://raw@${azurerm_storage_account.dl.name}.dfs.core.windows.net/"
|           credential_name = databricks_storage_credential.adls.name
|         }
|
└─ Databricks Secret Scope (stores secrets in the workspace; only needed for SP+secret auth)
    └─ keys like client-id / client-secret / tenant-id used by cluster spark_conf or notebooks
          e.g. store OAuth bits:
              resource "databricks_secret_scope" "adls" { name = "adls-creds" }
              resource "databricks_secret" "client_id" {
                scope        = databricks_secret_scope.adls.name
                key          = "client-id"
                string_value = azuread_application.dbx_to_adls_app.application_id
              }
              resource "databricks_secret" "client_secret" {
                scope        = databricks_secret_scope.adls.name
                key          = "client-secret"
                string_value = azuread_application_password.dbx_to_adls_secret.value
              }
              resource "databricks_secret" "tenant_id" {
                scope        = databricks_secret_scope.adls.name
                key          = "tenant-id"
                string_value = data.azurerm_client_config.current.tenant_id
              }
