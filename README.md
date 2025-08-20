# Terraform platform engineering for data pipelines
Provision a complete Azure data engineering sandbox with Terraform: Azure Data Lake Storage Gen2 (ADLS), Azure Databricks, Azure Data Factory (ADF), Azure SQL Database, and the required identities/permissions between them.

Scope: setup for DEV/PROD. You can extend the patterns here for PROD.

## Architecture (high level)
``` text
Microsoft Entra ID (Azure AD)
|
├─ App Registration      ───► Service Principal    → Azure RBAC on resources
|                     (used by Terraform/ADF/Databricks as needed)
|
├─ ADF                   ───► triggers pipelines and databricks notebooks
|
├─ Databricks workspace  ───► reads/writes ADLS, runs notebooks
|
└─ ADLS Gen2             ───► containers: bronze, silver, gold

Azure SQL DB  ◄── Not used in pipeline but still provisioned 

```

## What this repo creates

Resource groups for dev and prod environments and a managed resource group for Databricks

ADLS Gen2 account with medallion containers (bronze, silver, gold)

Databricks workspace (Standard by default)

Azure Data Factory (with linked service to ADLS, SQLDB, and Databricks)

Azure SQL Database 

## Extras
"notebook_scripts" folder contains pyspark notebook scripts processed customer data (bronze -> silver), and created aggregate total subcriptions by month (silver -> gold)


## Results
Dev resources
<img width="1473" height="704" alt="dev-rg" src="https://github.com/user-attachments/assets/7cd2822d-7e4e-456e-80c9-82f69549a339" />


Prod resources
<img width="1490" height="682" alt="prod-rg" src="https://github.com/user-attachments/assets/aab29192-9028-4ae7-8bba-d809d726ed90" />

Datalake with medallion folders
<img width="2505" height="603" alt="datalake_medallion_folders" src="https://github.com/user-attachments/assets/da81c5c9-b4e6-4c66-af70-d15204a85670" />

ADF with linked services 

<img width="2532" height="696" alt="adf_linked_services" src="https://github.com/user-attachments/assets/dd53c8bb-74f7-409f-996b-5bd8d2900efd" />

Example script

<img width="1224" height="1232" alt="subscribers_by_month_script" src="https://github.com/user-attachments/assets/ebc30d0b-4696-46fb-bce9-ca875a80f486" />

ADF Pipeline run successful

<img width="2536" height="1123" alt="adf_pipeline_successful" src="https://github.com/user-attachments/assets/43817cd1-b35d-4b20-bf2e-f0d390b92452" />

Subscribers by month table created








