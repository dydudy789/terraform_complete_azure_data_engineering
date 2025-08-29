set -euo pipefail

# destroy-one ENV TFVARS
destroy_one () {
  local ENV="$1"
  local TFVARS="$2"

  # Ensure workspace exists
  if ! terraform workspace list | sed 's/*//g' | awk '{$1=$1};1' | grep -qx "$ENV"; then
    echo "⚠️  Terraform workspace '$ENV' not found. Skipping."
    return 0
  fi

  echo ""
  echo "========================================"
  echo " Environment: $ENV"
  echo "========================================"

  terraform workspace select "$ENV" >/dev/null

  echo "📦 Resources tracked in state ($ENV):"
  # If no resources, this exits 0 with empty output
  terraform state list || true
  echo ""

  # Confirm for each environment
  read -r -p "Type '$ENV' to confirm destruction of $ENV: " ANSWER
  if [[ "$ANSWER" != "$ENV" ]]; then
    echo "❌ Confirmation mismatch. Aborting $ENV destroy."
    return 1
  fi

  # Extra guard for prod
  if [[ "$ENV" == "prod" ]]; then
    read -r -p "THIS IS PROD. Type 'DESTROY PROD' to continue: " P2
    if [[ "$P2" != "DESTROY PROD" ]]; then
      echo "❌ Second confirmation failed. Aborting prod destroy."
      return 1
    fi
  fi

  echo "🛠  Running terraform destroy for $ENV ..."
  terraform destroy -var-file="$TFVARS" -auto-approve
  echo "✅ Finished destroying $ENV."
}

echo "🔴 You are about to destroy Terraform-managed resources in DEV and PROD."
read -r -p "Type 'I UNDERSTAND' to proceed: " GLOBAL_OK
if [[ "$GLOBAL_OK" != "I UNDERSTAND" ]]; then
  echo "❌ Global confirmation failed. Exiting."
  exit 1
fi

# DEV
destroy_one "dev"  "dev.tfvars"

# PROD
destroy_one "prod" "prod.tfvars"

echo "✅ All done."