# providers.tf
terraform {
  required_providers {
    azurerm    = { source = "hashicorp/azurerm", version = "~> 4.40" }
    azuread    = { source = "hashicorp/azuread", version = "~> 2.50" }
    databricks = { source = "databricks/databricks", version = "~> 1.85" }
    random     = { source = "hashicorp/random", version = "~> 3.6" }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "b0383404-86dd-4235-ac9a-870f2065f00d"
  tenant_id       = "83696c1e-1424-49cd-b492-d64f3e551ee4"
}

# data reads information from provider so it can be used in configs
data "azurerm_client_config" "current" {}

# Get your user (by object id). Used to look up existing Entra group to set SQL Server Entra admin
data "azuread_user" "me" {
  object_id = data.azurerm_client_config.current.object_id
}

provider "azuread" {
  tenant_id = data.azurerm_client_config.current.tenant_id
}

# ---------- Databricks provider (for later when we add notebooks/jobs) ----------
provider "databricks" {
  auth_type                   = "azure-cli"
  azure_workspace_resource_id = var.databricks_workspace_id
}