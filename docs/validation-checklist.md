# Post-deploy validation checklist

Use this list after a successful deployment. Tick each item when verified.

- [ ] Virtual network exists with address space `10.0.0.0/16` (or the value you parameterized).
- [ ] Subnets `snet-app` and `snet-db` exist with CIDRs `10.0.1.0/24` and `10.0.2.0/24` (or your parameterized equivalents).
- [ ] NSG `nsg-db` is associated with subnet `snet-db`.
- [ ] Inbound rule on `nsg-db` allows TCP `1433` only from the app subnet CIDR (not from Internet).
- [ ] Both app VMs have a Standard public IP; the database VM has no public IP.
- [ ] All three VMs show **Running** in the portal (or `az vm list -d`).
- [ ] Each VM shows an attached Premium data disk at LUN 0 in the **Disks** blade (128 GB / 256 GB prod, or 64 GB dev).
- [ ] Private DNS zone `internal.contoso.local` exists under **Private DNS zones**.
- [ ] The VNet link to `vnet-prod` shows registration enabled and **Completed** (or healthy) link state.
- [ ] A records `app01`, `app02`, and `db01` exist in the zone with expected private IPs.
- [ ] SSH to `vm-app-01` succeeds using your private key (via its public IP).
- [ ] From `vm-app-01`, `nslookup db01.internal.contoso.local` returns the private IP of `vm-db-01`.
- [ ] `curl -s -o /dev/null -w "%{http_code}" http://localhost` on each app VM returns `200` (nginx default page).
- [ ] From your laptop, port `1433` to the **public** IP of `vm-app-01` is **not** an open SQL path to the DB subnet (NSG should block Internet → db); optional: confirm effective NSG on `snet-db` blocks Internet-originated SQL.
- [ ] Cost estimate for the resource group is reasonable for **dev** SKUs (`Standard_B1ms` app, `Standard_B2ms` DB, 64 GB disks—tune if your subscription policy requires other sizes); prod will be higher.
- [ ] Subnet **`snet-pe`** (`10.0.3.0/24` or your parameterized CIDR) exists for private endpoints.
- [ ] Storage account shows **Public network access** disabled and a **private endpoint** for sub-resource **blob** in **Approved** state.
- [ ] Private DNS zone **`privatelink.blob.core.windows.net`** (public Azure) exists and is **linked** to `vnet-prod`.
- [ ] From `vm-app-01`, `nslookup <storageAccount>.blob.core.windows.net` returns the **private endpoint** IP (match ARM output `blobPrivateEndpointIp`, or Bicep `blobPrivateEndpointNicId` + `az network nic show`).
