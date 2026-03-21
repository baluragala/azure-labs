// TEACHING NOTE: Managed disks are created as standalone resources first; compute then attaches them at VM creation (same effective outcome as attach-after, without a second PUT on the VM). `existing` in other modules refers to VMs created in compute—this module only owns disk RIDs.

@description('Azure region for managed disks.')
param location string

@description('Names of the two application VMs (used for disk naming).')
param appVmNames array

@description('Name of the Windows database VM (used for disk naming).')
param vmDbName string

@description('Size in GB for each app-tier Premium data disk.')
param appDataDiskSizeGb int

@description('Size in GB for the DB-tier Premium data disk.')
param dbDataDiskSizeGb int

resource appDataDisks 'Microsoft.Compute/disks@2023-04-02' = [for name in appVmNames: {
  name: '${name}-data'
  location: location
  sku: {
    name: 'Premium_LRS'
  }
  properties: {
    diskSizeGB: appDataDiskSizeGb
    creationData: {
      createOption: 'Empty'
    }
  }
}]

resource dbDataDisk 'Microsoft.Compute/disks@2023-04-02' = {
  name: '${vmDbName}-data'
  location: location
  sku: {
    name: 'Premium_LRS'
  }
  properties: {
    diskSizeGB: dbDataDiskSizeGb
    creationData: {
      createOption: 'Empty'
    }
  }
}

@description('Resource IDs of app-tier data disks (same order as appVmNames).')
output appDataDiskIds array = [for i in range(0, length(appVmNames)): appDataDisks[i].id]

@description('Resource ID of the database data disk.')
output dbDataDiskId string = dbDataDisk.id
