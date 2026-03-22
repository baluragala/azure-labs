# Lab: Azure networking, NSGs, VMs, Private DNS (ARM + Bicep)

## 1. Objective

By the end of this lab you will be able to:

- Deploy a **hub-style** production-like network: VNet, tiered subnets, and **Network Security Groups (NSGs)** aligned to subnets.
- Provision **Linux** application VMs (with public IPs for SSH in this lab) and a **private** Windows VM on a database subnet.
- Attach **Premium managed data disks** separate from OS disks.
- Configure **Azure Private DNS** with **auto-registration** and **manual A records** for stable internal names.
- Use **Private Link** to **Azure Blob Storage** (dedicated subnet, private endpoint, `privatelink.blob…` DNS) with **public network access disabled** on the account.
- Validate connectivity and DNS resolution from a jump/app host, and relate portal views (NSG effective rules, disks) to the template design.

---

## 2. Prerequisites

- An **Azure subscription** where you can create resource groups and VMs (Owner or Contributor on a subscription or resource group).
- **Azure CLI** installed (`az --version`) and able to run `az login`.
- **Visual Studio Code** with the **Bicep** extension (syntax, `bicep build`, parameter hints).
- An **SSH key pair**; you will paste the **public** key into parameters for the Linux VMs.
- A **strong Windows password** for `vm-db-01` (complexity requirements apply). Do **not** commit real secrets to Git—use environment variables or secure CI variables as shown in the deploy scripts.

---

## 3. Background concepts

For a fuller map of concepts to Azure resource types, diagrams, and module boundaries, see **[Concepts and architecture](./concepts-and-architecture.md)**.

### Virtual networks and subnets

An Azure **virtual network (VNet)** is a private IP space in a region. You carve it into **subnets** so you can assign different trust levels and policies: here, an **app** tier (`snet-app`) and a **db** tier (`snet-db`). Routing between subnets in the same VNet is allowed by default; **what is allowed at the TCP/UDP level** is enforced by **NSGs** and (for some designs) firewalls. Keeping tiers in separate subnets is a standard way to attach different NSGs and to grow toward hub-spoke or shared services later.

### Network Security Groups (NSGs)

An **NSG** is a stateful-ish list of **rules** (priority, source, destination, port, action). Rules are evaluated by **priority**; the first match wins for that direction. In this lab, **nsg-app** allows HTTP, HTTPS, and SSH from the Internet to the app subnet, then **denies** other inbound traffic at a low priority. **nsg-db** allows **only** SQL Server traffic (`1433`) from the **app subnet CIDR**, then denies other inbound—so random Internet hosts cannot reach the database tier even if a process listened on 1433.

### Managed disks vs “unmanaged”

**Managed disks** are standalone resources in your subscription; Azure handles storage accounts and scale limits. You size **OS** disks with the VM image and add **data** disks for application or database files. **Unmanaged** disks (legacy) required you to manage storage accounts and VHD URIs; new workloads should use **managed disks**. This lab uses **Premium SSD** data disks sized per environment (64 GB dev, 128/256 GB prod).

### Private DNS zones: auto-registration vs manual A records

A **Private DNS zone** (for example `internal.contoso.local`) resolves names **only inside linked VNets** (or other supported topologies). When you link a VNet with **auto-registration**, Azure DNS can **register** VM hostnames automatically as records in the zone. **Manual A records** (e.g. `app01`, `app02`, `db01`) give **predictable** names for scripts and documentation that do not depend on the VM’s computer name or registration timing. This lab uses **both**: registration for learning, plus explicit **A** records pointing at the **static private IPs** of the three VMs.

---

## 4. Lab tasks

Each task explains **what** you are doing and **why** it matters in real deployments.

### Task 1 — Choose environment and review parameters

**Why:** Production and dev differ in VM size and disk size; parameter files keep one template and multiple environments.

**What:** If you deploy with **`./scripts/deploy-bicep.sh`** or **`./scripts/deploy-arm.sh`**, an ed25519 key pair is created under **`.lab-ssh/`** when missing, and the public key is passed into the deployment automatically—use **`ssh -i .lab-ssh/id_ed25519`** (see the script’s completion message). For manual `az deployment` commands, edit `sshPublicKey` in the parameters JSON or pass `--parameters sshPublicKey="$(cat ~/.ssh/id_ed25519.pub)"`.

![Expected output](./screenshots/task-1.png)

---

### Task 2 — Log in and select subscription

**Why:** All resources are created in a subscription; wrong subscription means wrong billing and access policies.

**Exact command:**

```bash
az login
az account set --subscription "<your-subscription-id-or-name>"
```

Optional (automation-friendly):

```bash
export AZURE_SUBSCRIPTION_ID="<uuid>"
```

![Expected output](./screenshots/task-2.png)

---

### Task 3 — Validate the Bicep deployment (recommended before full deploy)

**Why:** Validation catches schema and policy errors without creating billable VMs.

**Exact command** (create an empty resource group first if needed):

```bash
export WINDOWS_ADMIN_PASSWORD='<strong-password>'
./scripts/validate-bicep.sh dev-rg dev eastus2
```

![Expected output](./screenshots/task-3.png)

---

### Task 4 — Deploy with Bicep (primary path)

**Why:** Modular Bicep matches how teams structure networking, compute, storage, and DNS.

**Exact command:**

```bash
export WINDOWS_ADMIN_PASSWORD='<strong-password>'
./scripts/deploy-bicep.sh dev-rg dev eastus2
```

For production-sized SKUs, use `prod` as the second argument and a resource group name you prefer (e.g. `prod-rg`).

![Expected output](./screenshots/task-4.png)

---

### Task 5 — (Optional) Deploy with ARM instead

**Why:** Many enterprises still maintain ARM JSON; this repo mirrors the same architecture.

**Exact command:**

```bash
export WINDOWS_ADMIN_PASSWORD='<strong-password>'
./scripts/deploy-arm.sh dev-rg dev eastus2
```

![Expected output](./screenshots/task-5.png)

---

### Task 6 — Record outputs

**Why:** Outputs give you VNet/subnet IDs and private IPs for automation and troubleshooting.

**Exact command:**

```bash
az deployment group show -g dev-rg -n lab-deploy --query properties.outputs -o json
```

(Deployments use the name `lab-deploy` from the provided scripts; list others with `az deployment group list -g dev-rg`.)

![Expected output](./screenshots/task-6.png)

---

## 5. Validation steps

Run these after a successful deploy.

1. **SSH** to `vm-app-01` using its **public IP** and your private key.
2. On `vm-app-01`, run:

   ```bash
   ping -c 3 db01.internal.contoso.local
   ```

   You should see the **private IP** of `vm-db-01` (ICMP may be blocked by guest firewall; if ping fails, rely on **nslookup** / **dig** for DNS validation).

3. On `vm-app-01`, run:

   ```bash
   nslookup db01.internal.contoso.local
   curl -s -I http://vm-app-02.internal.contoso.local
   ```

   DNS should resolve; **HTTP** should return nginx headers (`200`).

4. In the **Azure Portal**, open **Network security groups** → **nsg-db** → **Effective security rules** (or subnet association view) and confirm **Internet** is not a permitted source for SQL to the database tier—only the app subnet CIDR should allow **1433** inbound to that tier’s workloads.

5. **Blob over Private Link:** From the deployment outputs, note `blobStorageAccountName`. On `vm-app-01`, run:

   ```bash
   nslookup <blobStorageAccountName>.blob.core.windows.net
   ```

   The address returned should be a **private** IP in your VNet (the private endpoint), **not** a public Azure storage IP. Compare with the ARM output `blobPrivateEndpointIp`, or with the Bicep output `blobPrivateEndpointNicId` via:

   ```bash
   az network nic show --ids "<blobPrivateEndpointNicId>" --query "ipConfigurations[0].privateIpAddress" -o tsv
   ```

   Then verify HTTPS reaches the endpoint (expect **403** without auth—that still proves TLS to Blob over the private path):

   ```bash
   curl -s -o /dev/null -w "%{http_code}\n" "https://<blobStorageAccountName>.blob.core.windows.net/"
   ```

   In the portal, open the **storage account** → **Networking**: **Public network access** should be **Disabled**, and **Private endpoint connections** should show **Approved** for the `blob` target.

6. **Subscription policy (e.g. allowed VM SKUs):** If deployment fails with `RequestDisallowedByPolicy` on VM sizes, your `parameters.*.json` **vmAppSize** / **vmDbSize** must match the policy allow-list. The dev parameter files use **Standard_B1ms** (app) and **Standard_B2ms** (Windows DB), which align with common “allow B-series / specific sizes” policies; adjust to your tenant’s list if needed.

---

## 7. Teardown

**Why:** Lab VMs and public IPs incur cost; deleting the **resource group** guarantees all nested resources are removed.

**Exact command:**

```bash
./scripts/cleanup.sh dev-rg
```

The script deletes the group **asynchronously** (`--no-wait`). Confirm in the portal that the resource group disappears.

---

## 8. Challenge extensions (optional)

- Replace public IPs on app VMs with **Azure Bastion** in a dedicated subnet for browser-based SSH (no SSH from Internet to public IPs).
- Add **VNet peering** to a second “management” VNet used only by admins and monitoring.
- Split the ARM template into a **linked template** deployment: base networking in one template, compute in another, with outputs passed between deployments.
