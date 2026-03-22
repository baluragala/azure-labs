#!/usr/bin/env bash
# Validate ARM template without applying (requires existing resource group).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=lib-lab-ssh.sh
source "${SCRIPT_DIR}/lib-lab-ssh.sh"

SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-}"
if [[ -z "${SUBSCRIPTION_ID}" ]]; then
  SUBSCRIPTION_ID="$(az account show --only-show-errors --query id -o tsv 2>/dev/null || true)"
fi
if [[ -z "${SUBSCRIPTION_ID}" ]]; then
  echo "error: No Azure subscription. Set AZURE_SUBSCRIPTION_ID or run: az login" >&2
  exit 1
fi

RG_NAME="${1:-dev-rg}"
ENV_NAME="${2:-dev}"
LOCATION="${3:-eastus2}"
PARAM_FILE="${ROOT_DIR}/arm/parameters.${ENV_NAME}.json"

if [[ -z "${WINDOWS_ADMIN_PASSWORD:-}" ]]; then
  echo "error: Set WINDOWS_ADMIN_PASSWORD for validation (secureString parameter)." >&2
  exit 1
fi

ensure_lab_ssh_key "${ROOT_DIR}"
SSH_PUBLIC_KEY_VALUE="$(lab_ssh_public_key_value)"

az account set --subscription "${SUBSCRIPTION_ID}" --only-show-errors

if ! az group show --name "${RG_NAME}" --only-show-errors &>/dev/null; then
  az group create --name "${RG_NAME}" --location "${LOCATION}" --only-show-errors
fi

az deployment group validate \
  --name lab-deploy \
  --resource-group "${RG_NAME}" \
  --template-file "${ROOT_DIR}/arm/azuredeploy.json" \
  --parameters "@${PARAM_FILE}" \
  --parameters windowsAdminPassword="${WINDOWS_ADMIN_PASSWORD}" \
  --parameters sshPublicKey="${SSH_PUBLIC_KEY_VALUE}" \
  --only-show-errors

echo "ARM template validation succeeded."
