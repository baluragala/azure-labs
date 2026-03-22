#!/usr/bin/env bash
# Deploy ARM template (azuredeploy.json) to an existing resource group (creates RG if missing).
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

if [[ ! -f "${PARAM_FILE}" ]]; then
  echo "error: Missing parameters file: ${PARAM_FILE}" >&2
  exit 1
fi

if [[ -z "${WINDOWS_ADMIN_PASSWORD:-}" ]]; then
  echo "error: Set WINDOWS_ADMIN_PASSWORD (Windows VM admin password, meets Azure complexity)." >&2
  exit 1
fi

ensure_lab_ssh_key "${ROOT_DIR}"
SSH_PUBLIC_KEY_VALUE="$(lab_ssh_public_key_value)"

az account set --subscription "${SUBSCRIPTION_ID}" --only-show-errors

if ! az group show --name "${RG_NAME}" --only-show-errors &>/dev/null; then
  az group create --name "${RG_NAME}" --location "${LOCATION}" --only-show-errors
fi

az deployment group create \
  --name lab-deploy \
  --resource-group "${RG_NAME}" \
  --template-file "${ROOT_DIR}/arm/azuredeploy.json" \
  --parameters "@${PARAM_FILE}" \
  --parameters windowsAdminPassword="${WINDOWS_ADMIN_PASSWORD}" \
  --parameters sshPublicKey="${SSH_PUBLIC_KEY_VALUE}" \
  --only-show-errors

echo "Deployment finished for resource group: ${RG_NAME}"
if [[ -z "${SSH_PUBLIC_KEY:-}" ]] && [[ -n "${LAB_SSH_PRIVATE_KEY:-}" ]]; then
  echo "SSH to Linux VMs: ssh -i ${LAB_SSH_PRIVATE_KEY} azureuser@<app-vm-public-ip>"
fi
