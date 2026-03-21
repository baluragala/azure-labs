# Azure labs — networking VM lab

This repo implements the infrastructure and documentation described in [`lab.md`](./lab.md).

| Path | Purpose |
|------|---------|
| [`arm/azuredeploy.json`](./arm/azuredeploy.json) | ARM template (single file) |
| [`arm/parameters.dev.json`](./arm/parameters.dev.json) / [`arm/parameters.prod.json`](./arm/parameters.prod.json) | Environment-specific parameters |
| [`bicep/main.bicep`](./bicep/main.bicep) | Modular Bicep entrypoint |
| [`bicep/network.bicep`](./bicep/network.bicep), [`compute.bicep`](./bicep/compute.bicep), [`storage.bicep`](./bicep/storage.bicep), [`dns.bicep`](./bicep/dns.bicep) | Modules |
| [`scripts/`](./scripts/) | Deploy, validate, cleanup (executable) |
| [`docs/lab-guide.md`](./docs/lab-guide.md) | Student lab guide |
| [`docs/validation-checklist.md`](./docs/validation-checklist.md) | Post-deploy checklist |

**Secrets:** set `WINDOWS_ADMIN_PASSWORD` before deploy/validate. Replace the placeholder SSH public key in parameter files. Optionally set `AZURE_SUBSCRIPTION_ID` instead of relying on the default CLI subscription.

Quick validate (Bicep):

```bash
export WINDOWS_ADMIN_PASSWORD='YourComplexPassword123!'
./scripts/validate-bicep.sh dev-rg dev eastus2
```

Quick deploy (Bicep):

```bash
export WINDOWS_ADMIN_PASSWORD='YourComplexPassword123!'
./scripts/deploy-bicep.sh dev-rg dev eastus2
```

Teardown:

```bash
./scripts/cleanup.sh dev-rg
```
