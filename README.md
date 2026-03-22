# Azure labs — networking VM lab

This repo implements the infrastructure and documentation described in [`lab.md`](./lab.md). It includes **Private Link to Azure Blob Storage** (private endpoint in `snet-pe`, `privatelink.blob…` DNS, storage public access disabled). See [`docs/concepts-and-architecture.md`](./docs/concepts-and-architecture.md) for how that differs from internal VM Private DNS.

| Path | Purpose |
|------|---------|
| [`arm/azuredeploy.json`](./arm/azuredeploy.json) | ARM template (single file) |
| [`arm/parameters.dev.json`](./arm/parameters.dev.json) / [`arm/parameters.prod.json`](./arm/parameters.prod.json) | Environment-specific parameters |
| [`bicep/main.bicep`](./bicep/main.bicep) | Modular Bicep entrypoint |
| [`bicep/network.bicep`](./bicep/network.bicep), [`compute.bicep`](./bicep/compute.bicep), [`storage.bicep`](./bicep/storage.bicep), [`dns.bicep`](./bicep/dns.bicep), [`blob-privatelink.bicep`](./bicep/blob-privatelink.bicep) | Modules |
| [`scripts/`](./scripts/) | Deploy, validate, cleanup (executable) |
| [`docs/lab-guide.md`](./docs/lab-guide.md) | Student lab guide |
| [`docs/concepts-and-architecture.md`](./docs/concepts-and-architecture.md) | Concepts, Azure services, and how they link |
| [`docs/validation-checklist.md`](./docs/validation-checklist.md) | Post-deploy checklist |

**Secrets:** set `WINDOWS_ADMIN_PASSWORD` before deploy/validate. Optionally set `AZURE_SUBSCRIPTION_ID` instead of relying on the default CLI subscription.

**SSH key:** The **`./scripts/deploy-*.sh`** and **`./scripts/validate-*.sh`** scripts create **`./.lab-ssh/id_ed25519`** on first run (gitignored), pass the **public** key to Azure, and print the `ssh -i ...` hint after deploy. To use your own key instead, set **`SSH_PUBLIC_KEY`** to the one-line public key before running the script. Parameter JSON files still contain a fallback public key for manual `az deployment` runs.

**Policy:** Some subscriptions deny VM SKUs not on an allow-list (e.g. `Standard_B1s`). The **dev** parameter files use **`Standard_B1ms`** (Linux app) and **`Standard_B2ms`** (Windows DB), which match many IITB-style policies. Change `vmAppSize` / `vmDbSize` in your parameters JSON if your tenant requires different sizes.

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
