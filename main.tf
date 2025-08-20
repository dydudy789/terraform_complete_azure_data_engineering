# Random suffix for resource naming
resource "random_string" "sa" {
  length  = 5
  upper   = false
  lower   = true
  numeric = true
  special = false
}


# ---------- Create resource name variables ----------

locals {
  # name prefix is project + env
  name_prefix = "${var.project}-${var.env}"
  suffix = random_string.sa.result

  # For resources that ALLOW hyphens (ADF, Databricks, SQL server etc.)
  name_with_dash_rand  = "${local.name_prefix}-${local.suffix}"

  # For resources that REQUIRE only [a-z0-9] (Storage Account)
  # remove JUST the hyphen
  name_allnum_with_rand = "${replace(local.name_prefix, "-", "")}${local.suffix}"

  # ---- Final per-service names (respecting max lengths) ----
  rgname          = "rg-${local.name_with_dash_rand}"
  storage_account = "st${local.name_allnum_with_rand}"  # SA: ≤24, a–z0–9
  data_factory    = "adf-${local.name_with_dash_rand}"  # ADF: ≤63, hyphens ok
  databricks_ws   = "adb-${local.name_with_dash_rand}"  
  sql_server      = "sql-${local.name_with_dash_rand}"  # sql server (globally unique)
  sql_database    = "sqldb-${local.name_with_dash_rand}"

}

# ---------- Azure Resource Group ----------
resource "azurerm_resource_group" "rg" {
  name     = local.rgname
  location = var.location
}