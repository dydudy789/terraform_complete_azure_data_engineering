# terraform_complete_azure_data_engineering
Using terraform create azure resources including ADLS, databricks, azure data factory, and azure sql db.  Also give permissions between resources. Then build a basic pipeline


# Reference material for access and authentication between Azure resources

# terraform_complete_azure_data_engineering
Using terraform create azure resources including ADLS, Databricks, Azure Data Factory, and Azure SQL DB. Also give permissions between resources. Then build a basic pipeline.

Microsoft Entra ID (Azure AD)
|
├─ App Registration  → the app’s **login name** (think: username for an app)
|   └─ application_id (client_id)   ← use this when the app **signs in** with a secret/cert, or when registering it in Databricks
|      e.g. Databricks SCIM registration:
|          application_id = data.azuread_service_principal.adf_mi.application_id
|          # or if you created your own app:
|          # application_id = azuread_application.dbx_to_adls_app.application_id
|   └─ object_id  ← the “row ID” of this app in Entra; used when creating a client-secret
|      e.g. create secret for the app:
|          application_object_id = azuread_application.dbx_to_adls_app.object_id
|
└─ Service Principal  → the app’s **account** in your tenant (this is what gets Azure RBAC)
    └─ object_id  ← paste this into Azure RBAC role assignments (who gets access)
       e.g. grant storage access:
           principal_id = azuread_service_principal.dbx_to_adls_sp.object_id
    └─ application_id (client_id) → points back to the App Registration (same “username”)

Azure resources
|
├─ ADF (system-assigned Managed Identity)
|   └─ principal_id  ← the built-in account for ADF (internally it’s an SP ID)
|      e.g. ADF → ADLS (no secrets; just RBAC):
|          principal_id = azurerm_data_factory.adf.identity[0].principal_id
|      e.g. look up ADF’s identity as an SP to get its application_id:
|          data "azuread_service_principal" "adf_mi" {
|            object_id = azurerm_data_factory.adf.identity[0].principal_id
|          }
|
└─ ADLS storage account
    └─ id  ← the Azure resource path; use as the **scope** in RBAC
        e.g. scope = azurerm_storage_account.dl.id

Databricks workspace
|
├─ Databricks Service Principal (SCIM record)
|   └─ id (Databricks-internal) ← use this for **Databricks permissions**
|      e.g. register ADF MI in Databricks (so you can assign DBX permissions):
|          resource "databricks_service_principal" "registered_adf_mi" {
|            application_id = data.azuread_service_principal.adf_mi.application_id
|            display_name   = "adf-${var.project}-${var.env}"
|            active         = true
|          }
|      e.g. grant workspace access in Databricks:
|          resource "databricks_entitlements" "adf_mi_workspace_access" {
|            service_principal_id = databricks_service_principal.registered_adf_mi.id
|            workspace_access     = true
|          }
|
└─ Databricks Secret Scope (stores secrets **in** the workspace)
    └─ keys like client-id / client-secret / tenant-id → used by cluster spark_conf or notebooks (only needed for SP+secret auth)
       e.g. store OAuth bits for classic mounts:
|          resource "databricks_secret_scope" "adls" { name = "adls-creds" }
|          resource "databricks_secret" "client_id" {
|            scope        = databricks_secret_scope.adls.name
|            key          = "client-id"
|            string_value = azuread_application.dbx_to_adls_app.application_id
|          }
|          resource "databricks_secret" "client_secret" {
|            scope        = databricks_secret_scope.adls.name
|            key          = "client-secret"
|            string_value = azuread_application_password.dbx_to_adls_secret.value
|          }
|          resource "databricks_secret" "tenant_id" {
|            scope        = databricks_secret_scope.adls.name
|            key          = "tenant-id"
|            string_value = data.azurerm_client_config.current.tenant_id
|          }
|       e.g. use them in a cluster’s spark_conf (per-account endpoint shown):
|          "spark.hadoop.fs.azure.account.oauth2.client.id.${local.sa}.dfs.core.windows.net"     = "{{secrets/adls-creds/client-id}}"
|          "spark.hadoop.fs.azure.account.oauth2.client.secret.${local.sa}.dfs.core.windows.net" = "{{secrets/adls-creds/client-secret}}"
|          "spark.hadoop.fs.azure.account.oauth2.client.endpoint.${local.sa}.dfs.core.windows.net" = "https://login.microsoftonline.com/{{secrets/adls-creds/tenant-id}}/oauth2/token"

# Extra examples you’ll likely need

- Azure RBAC to a classic Service Principal (SP) for ADLS:
|  resource "azurerm_role_assignment" "adls_blob_contributor_for_dbx_sp" {
|    scope                            = azurerm_storage_account.dl.id
|    role_definition_name             = "Storage Blob Data Contributor"
|    principal_id                     = azuread_service_principal.dbx_to_adls_sp.object_id
|    skip_service_principal_aad_check = true
|  }

- Azure RBAC to ADF’s Managed Identity (no secrets):
|  resource "azurerm_role_assignment" "adf_storage_contrib" {
|    scope                = azurerm_storage_account.dl.id
|    role_definition_name = "Storage Blob Data Contributor"
|    principal_id         = azurerm_data_factory.adf.identity[0].principal_id
|  }

- (No-secrets path) Databricks Access Connector + Unity Catalog (recommended for production):
|  # Requires **Databricks Premium (or higher)**.
|  resource "azurerm_databricks_access_connector" "uc" {
|    name                = "ac-${var.project}-${var.env}"
|    resource_group_name = azurerm_resource_group.rg.name
|    location            = var.location
|    identity { type = "SystemAssigned" }
|  }
|  resource "azurerm_role_assignment" "uc_to_adls" {
|    scope                = azurerm_storage_account.dl.id
|    role_definition_name = "Storage Blob Data Contributor"
|    principal_id         = azurerm_databricks_access_connector.uc.identity[0].principal_id
|  }
|  resource "databricks_storage_credential" "adls" {
|    name = "cred-adls"
|    azure_managed_identity { access_connector_id = azurerm_databricks_access_connector.uc.id }
|  }
|  resource "databricks_external_location" "raw" {
|    name            = "loc-raw"
|    url             = "abfss://raw@${azurerm_storage_account.dl.name}.dfs.core.windows.net/"
|    credential_name = databricks_storage_credential.adls.name
|  }

# One-liners to remember
- **object_id** = the unique ID of any identity in Entra (user / group / service principal / app).  
  Use it in Azure RBAC: `principal_id = <that object_id>`.
- **principal_id** (on Azure resources) = the Managed Identity’s **service principal ID** (same shape as object_id).  
  Use it the same way in RBAC: `principal_id = azurerm_*.*.identity[0].principal_id`.
- **application_id (client_id)** = the app’s **login name**. Use it only when an app **signs in** (with a secret/cert) or when **registering** that identity inside Databricks.
- **tenant_id** = your org’s ID; it appears in OAuth URLs and some linked services.






