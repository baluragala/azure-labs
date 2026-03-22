// Orchestration order: network → managed data disks → VMs → internal Private DNS → Blob Storage + Private Link.
// Blob Private Link only needs the VNet and PE subnet; it is deployed after core infra so outputs stay grouped.

targetScope = 'resourceGroup'

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Logical resource group name (documentation only).')
param resourceGroupName string

@description('Name of the virtual network.')
param vnetName string

@description('Address space for the VNet (CIDR).')
param vnetAddressPrefix string

@description('Name of the application tier subnet.')
param subnetAppName string

@description('CIDR for the application subnet.')
param subnetAppPrefix string

@description('Name of the database tier subnet.')
param subnetDbName string

@description('CIDR for the database subnet.')
param subnetDbPrefix string

@description('Name of the NSG attached to the app subnet.')
param nsgAppName string

@description('Name of the NSG attached to the db subnet.')
param nsgDbName string

@description('Name of the subnet used for the blob private endpoint.')
param subnetPeName string

@description('CIDR for the private endpoint subnet.')
param subnetPePrefix string

@description('Name of the private endpoint to Blob Storage.')
param blobPrivateEndpointName string

@description('VNet link name under the Azure blob Private DNS zone (privatelink.blob.<storage-suffix>).')
param blobPrivateDnsVnetLinkName string

@description('Names of the two Ubuntu application VMs.')
param appVmNames array

@description('Static private IPs for app VMs (same order as appVmNames).')
param appPrivateIps array

@description('Name of the Windows database VM.')
param vmDbName string

@description('Static private IP for the database VM.')
param vmDbPrivateIp string

@description('VM size for Linux app tier.')
param vmAppSize string

@description('VM size for Windows DB tier.')
param vmDbSize string

@description('Size in GB for each app-tier Premium data disk.')
param appDataDiskSizeGb int

@description('Size in GB for the DB-tier Premium data disk.')
param dbDataDiskSizeGb int

@description('Linux administrator username (SSH).')
param linuxAdminUsername string

@description('SSH public key for Linux VMs.')
param sshPublicKey string

@description('Windows administrator username.')
param windowsAdminUsername string

@description('Windows administrator password.')
@secure()
param windowsAdminPassword string

@description('Private DNS zone name.')
param privateDnsZoneName string

@description('Unique suffix for the Private DNS VNet link name.')
param vnetDnsLinkName string

module network 'network.bicep' = {
  name: 'network'
  params: {
    resourceGroupName: resourceGroupName
    location: location
    vnetName: vnetName
    vnetAddressPrefix: vnetAddressPrefix
    subnetAppName: subnetAppName
    subnetAppPrefix: subnetAppPrefix
    subnetDbName: subnetDbName
    subnetDbPrefix: subnetDbPrefix
    nsgAppName: nsgAppName
    nsgDbName: nsgDbName
    subnetPeName: subnetPeName
    subnetPePrefix: subnetPePrefix
  }
}

module storage 'storage.bicep' = {
  name: 'storage'
  params: {
    location: location
    appVmNames: appVmNames
    vmDbName: vmDbName
    appDataDiskSizeGb: appDataDiskSizeGb
    dbDataDiskSizeGb: dbDataDiskSizeGb
  }
}

module compute 'compute.bicep' = {
  name: 'compute'
  params: {
    location: location
    appSubnetId: network.outputs.appSubnetId
    dbSubnetId: network.outputs.dbSubnetId
    appVmNames: appVmNames
    appPrivateIps: appPrivateIps
    vmDbName: vmDbName
    vmDbPrivateIp: vmDbPrivateIp
    vmAppSize: vmAppSize
    vmDbSize: vmDbSize
    linuxAdminUsername: linuxAdminUsername
    sshPublicKey: sshPublicKey
    windowsAdminUsername: windowsAdminUsername
    windowsAdminPassword: windowsAdminPassword
    appDataDiskIds: storage.outputs.appDataDiskIds
    dbDataDiskId: storage.outputs.dbDataDiskId
  }
}

module dns 'dns.bicep' = {
  name: 'dns'
  params: {
    vnetId: network.outputs.vnetId
    vnetLinkName: vnetDnsLinkName
    privateDnsZoneName: privateDnsZoneName
    app01PrivateIp: compute.outputs.vmPrivateIps[0]
    app02PrivateIp: compute.outputs.vmPrivateIps[1]
    db01PrivateIp: compute.outputs.vmPrivateIps[2]
  }
}

module blobPrivateLink 'blob-privatelink.bicep' = {
  name: 'blobPrivateLink'
  params: {
    location: location
    privateEndpointSubnetId: network.outputs.peSubnetId
    vnetId: network.outputs.vnetId
    privateEndpointName: blobPrivateEndpointName
    blobPrivateDnsVnetLinkName: blobPrivateDnsVnetLinkName
  }
}

@description('Resource ID of the virtual network.')
output vnetId string = network.outputs.vnetId

@description('Resource ID of the application subnet.')
output appSubnetId string = network.outputs.appSubnetId

@description('Resource ID of the database subnet.')
output dbSubnetId string = network.outputs.dbSubnetId

@description('Private IP addresses for VMs in order: app01, app02, db.')
output vmPrivateIps array = compute.outputs.vmPrivateIps

@description('Resource ID of the private DNS zone.')
output privateDnsZoneId string = dns.outputs.privateDnsZoneId

@description('Storage account name created for Private Link blob demo.')
output blobStorageAccountName string = blobPrivateLink.outputs.storageAccountName

@description('HTTPS blob endpoint (resolves to private IP inside linked VNets).')
output blobEndpointUri string = blobPrivateLink.outputs.blobEndpointUri

@description('Resource ID of the NIC created for the blob private endpoint; query its ipConfigurations for the private IP (see lab guide).')
output blobPrivateEndpointNicId string = reference(resourceId('Microsoft.Network/privateEndpoints', blobPrivateEndpointName), '2023-09-01').properties.networkInterfaces[0].id

@description('Resource ID of the Private DNS zone used for blob Private Link.')
output blobPrivateDnsZoneId string = blobPrivateLink.outputs.blobPrivateDnsZoneId
