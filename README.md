# Terraform platform engineering for data pipelines
Provision a complete Azure data engineering sandbox with Terraform: Azure Data Lake Storage Gen2 (ADLS), Azure Databricks, Azure Data Factory (ADF), Azure SQL Database, and the required identities/permissions between them.

Scope: setup for DEV/PROD. You can extend the patterns here for PROD.

## Architecture (high level)

Microsoft Entra ID (Azure AD)
|
├─ App Registration  → Service Principal    → Azure RBAC on resources
|                     (used by Terraform/ADF/Databricks as needed)
|
├─ ADF (factory + MI) ───► triggers pipelines / jobs
|
├─ Databricks workspace ─► reads/writes ADLS, runs notebooks/jobs
|
└─ ADLS Gen2 (containers: land, work, qa, core, ref)

Azure SQL DB  ◄── ADF ingest / Databricks write



## What this repo creates

Resource group(s) for your chosen environment (e.g., rg-<project>-<env> and a managed RG for Databricks)

ADLS Gen2 account with common containers (land, work, qa, core, ref)

Databricks workspace (Standard by default)

Azure Data Factory (optionally linked to Databricks)

Azure SQL Database + optional firewall rules

Access control links (examples):

Databricks SP/MI → ADLS (Storage Blob Data Contributor)

ADF MI → Databricks (jobs) or ADLS (as needed)

(Optional) Remote backend pattern for Terraform state
