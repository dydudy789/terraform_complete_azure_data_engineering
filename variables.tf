variable "project" { type = string }
variable "env" { type = string }
variable "location" { type = string }

variable "sql_admin_login" {
  type        = string
  description = "Temporary SQL admin login (switch to AAD MSI later)."
}

variable "sql_admin_password" {
  type        = string
  sensitive   = true
  description = "Temporary SQL admin password."
}

/*
variable "databricks_workspace_id" {
  description = "ARM ID of the target Databricks workspace"
  type        = string
}
*/