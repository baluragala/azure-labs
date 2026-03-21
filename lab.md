---

## INFRASTRUCTURE SPECS

### Resource Group
- Name: `prod-rg` (parameterised)
- Location: `eastus2` (parameterised)

### Virtual Network
- Name: `vnet-prod`
- Address space: `10.0.0.0/16`
- Subnets:
  - `snet-app` → `10.0.1.0/24` (App tier)
  - `snet-db`  → `10.0.2.0/24` (DB tier)

### Network Security Groups
- `nsg-app`: Allow inbound HTTP (80), HTTPS (443), SSH (22) from Internet; deny all else inbound
- `nsg-db`:  Allow inbound port 1433 from `snet-app` ONLY; deny all else inbound; associate to `snet-db`

### Virtual Machines
App tier (x2):
- Names: `vm-app-01`, `vm-app-02`
- OS: Ubuntu 22.04 LTS (`UbuntuServer`, `22_04-lts-gen2`)
- Size: `Standard_B2s`
- Auth: SSH public key (parameterised, no hardcoded passwords)
- Subnet: `snet-app`
- Public IP: Yes (for lab SSH access; note in docs this would be removed in real prod)

DB tier (x1):
- Name: `vm-db-01`
- OS: Windows Server 2022 Datacenter (`WindowsServer`, `2022-Datacenter`)
- Size: `Standard_B2ms`
- Auth: Admin username + password (parameterised, stored as secureString)
- Subnet: `snet-db`
- Public IP: No (private only — students access via vm-app-01 as jump host)

### Managed Disks (Data Disks — NOT OS disks)
- `vm-app-01` and `vm-app-02`: each gets one 128 GB Premium SSD data disk (`lun: 0`)
- `vm-db-01`: gets one 256 GB Premium SSD data disk (`lun: 0`) — for SQL data files

### Azure Private DNS Zone
- Zone name: `internal.contoso.local`
- VNet link: Link to `vnet-prod` with auto-registration ENABLED
- Manual A records (in addition to auto-registered):
  - `app01.internal.contoso.local` → static private IP of `vm-app-01`
  - `app02.internal.contoso.local` → static private IP of `vm-app-02`
  - `db01.internal.contoso.local`  → static private IP of `vm-db-01`

---

## REQUIREMENTS FOR ARM TEMPLATE (arm/azuredeploy.json)

- Use `$schema`: `https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#`
- All resource names must use `parameters` — no hardcoded strings except for resource types
- Use `dependsOn` correctly (NSG before Subnet, VNet before NIC, NIC before VM, VM before data disk attach)
- VM extensions: add `CustomScriptExtension` on Linux VMs that runs:
  `sudo apt-get update && sudo apt-get install -y nginx`
  (This lets students validate the VM is running after deploy)
- Use `outputs` section to export: VNet ID, Subnet IDs, all VM private IPs, DNS zone ID
- Split parameters file into `dev` (smaller SKUs: Standard_B1s, 64 GB disks) and `prod` (full spec above)

---

## REQUIREMENTS FOR BICEP (bicep/main.bicep + modules)

- Use Bicep `targetScope = 'resourceGroup'`
- Each module must have: `@description()` decorators on every param, typed params (no `object` where specific type works), and `output` for key resource IDs/IPs
- `network.bicep`: outputs `vnetId`, `appSubnetId`, `dbSubnetId`
- `compute.bicep`: takes subnet IDs as input params; outputs all VM private IPs as an array
- `storage.bicep`: takes VM resource IDs; attaches data disks (use `existing` resource reference)
- `dns.bicep`: takes VNet ID and VM private IPs as inputs; creates zone, VNet link, and A records
- `main.bicep`: orchestrates all modules, passes outputs between them
- Use `@secure()` on all password/key params
- Use Bicep loops (`for`) to create the two app VMs and their disks — DRY, not duplicated blocks

---

## LAB GUIDE (docs/lab-guide.md)

Write a complete student lab guide in Markdown with these sections:

### Lab Guide Structure

1. **Objective** — what the student will learn
2. **Prerequisites** — Azure subscription, az CLI installed, VS Code + Bicep extension
3. **Background concepts** — 3–4 paragraphs explaining: VNets & subnets, NSGs, Managed Disks vs unmanaged, Private DNS zones (how auto-registration works vs manual A records)
4. **Lab Tasks** — numbered tasks, each with:
   - What you're doing and WHY (real-world reason)
   - The exact az CLI command to deploy
   - Screenshot placeholder: `![Expected output](./screenshots/task-N.png)`
5. **Validation Steps** — students must run these after deploy:
   - SSH into `vm-app-01`, ping `db01.internal.contoso.local` → should resolve
   - From `vm-app-01`, curl `http://vm-app-02.internal.contoso.local` → should return nginx default page
   - In Azure Portal: verify NSG effective rules on `snet-db` block port 1433 from Internet
6. **Teardown** — run `cleanup.sh`, explain why you should always delete lab resources
7. **Challenge Extensions** (optional, for advanced students):
   - Add a Bastion host instead of public IPs on app VMs
   - Add a VNet peering to a second "management" VNet
   - Convert the ARM template outputs to be consumed by a second linked template

---

## VALIDATION CHECKLIST (docs/validation-checklist.md)

Create a markdown checklist with 15 items students tick off post-deploy:

- VNet exists with correct address space
- Both subnets created with correct CIDRs
- NSG `nsg-db` associated to `snet-db`
- Inbound rule on `nsg-db` allows only `snet-app` on port 1433
- Both app VMs have public IPs; db VM has no public IP
- All three VMs show as Running
- Data disks attached and showing in VM's disk blade
- Private DNS zone `internal.contoso.local` exists
- VNet link shows Completed registration status
- A records for app01, app02, db01 exist
- SSH to `vm-app-01` succeeds using the key
- `nslookup db01.internal.contoso.local` from `vm-app-01` returns correct private IP
- nginx returns 200 on `vm-app-01` and `vm-app-02`
- Port 1433 unreachable from `vm-app-01` public IP (NSG blocking Internet)
- Resource Group total cost estimate under $15/day (dev SKUs)

---

## CODING STANDARDS

- ARM JSON: 2-space indent, comments via `metadata` fields on each resource
- Bicep: use `//` comments explaining each non-obvious decision
- No az CLI commands in scripts that hardcode subscription IDs — use `az account show` or require env var `AZURE_SUBSCRIPTION_ID`
- Scripts must be idempotent where possible (use `--only-show-errors`, check existence before create)
- All scripts: `set -euo pipefail` at top

---

## TEACHING NOTES TO EMBED IN CODE COMMENTS

Add `// TEACHING NOTE:` comments at these key points:

- In ARM: why `dependsOn` is needed for NICs (ARM's parallel deployment model)
- In ARM: why `secureString` matters and what happens if you use plain `string` for passwords
- In Bicep: what `existing` resource reference does vs re-declaring a resource
- In Bicep: why `@secure()` params don't appear in deployment history
- In dns.bicep: difference between auto-registration and manual A records — when to use each
- In network.bicep: why NSG is on the subnet, not the NIC, in this design

---

## DELIVERABLE QUALITY BAR

- All ARM and Bicep templates must pass `az deployment group validate` without errors
- Bicep must pass `bicep build` without warnings
- The deploy scripts must be executable and work end-to-end in a clean Azure subscription
- Lab guide must be written for an intermediate engineer (knows Linux basics, new to Azure networking)
- Every `parameter` in ARM and every `param` in Bicep must have a `metadata.description` or `@description()`

Start by creating the folder structure, then build each file fully. Do not scaffold empty files — write complete, deployable content for every file.
