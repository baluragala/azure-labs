#!/usr/bin/env bash
# Delete the lab resource group and all nested resources (async).
set -euo pipefail

SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-}"
if [[ -z "${SUBSCRIPTION_ID}" ]]; then
  SUBSCRIPTION_ID="$(az account show --only-show-errors --query id -o tsv 2>/dev/null || true)"
fi
if [[ -z "${SUBSCRIPTION_ID}" ]]; then
  echo "error: No Azure subscription. Set AZURE_SUBSCRIPTION_ID or run: az login" >&2
  exit 1
fi

RG_NAME="${1:?Usage: cleanup.sh <resource-group-name>}"

az account set --subscription "${SUBSCRIPTION_ID}" --only-show-errors

if [[ "$(az group exists --name "${RG_NAME}" --only-show-errors -o tsv)" == "true" ]]; then
  echo "Deleting resource group: ${RG_NAME} (no wait; check portal for completion)"
  az group delete --name "${RG_NAME}" --yes --no-wait --only-show-errors
else
  echo "Resource group '${RG_NAME}' does not exist; nothing to delete."
fi
