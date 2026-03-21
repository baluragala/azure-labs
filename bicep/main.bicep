// Orchestration order: network → empty managed disks → VMs (attach disks at create) → Private DNS.
// Disks are defined before VMs so the attach uses stable resource IDs; this matches the ARM single-template pattern.

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
