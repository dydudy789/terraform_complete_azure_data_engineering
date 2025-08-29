set -euo pipefail

# 0) login to Azure (only needed if you’re not already logged in)
az login --use-device-code
az account set --subscription "Subscription 1"

# 1) re-init backend/providers (do this once if backend or state changed)
terraform init -reconfigure

# 2) DEV
terraform workspace new dev || true
terraform workspace select dev
terraform plan  -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars -auto-approve

# 3) PROD
terraform workspace new prod || true
terraform workspace select prod
terraform plan  -var-file=prod.tfvars
terraform apply -var-file=prod.tfvars -auto-approve