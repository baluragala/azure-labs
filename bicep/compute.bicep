// TEACHING NOTE: `@secure()` parameters are not echoed in deployment history or portal logs—unlike plain strings—reducing accidental password leakage.

@description('Azure region for compute resources.')
param location string

@description('Resource ID of the application subnet.')
param appSubnetId string

@description('Resource ID of the database subnet.')
param dbSubnetId string

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

@description('Linux administrator username (SSH).')
param linuxAdminUsername string

@description('SSH public key for Linux VMs (public material; not marked @secure()).')
param sshPublicKey string

@description('Windows administrator username.')
param windowsAdminUsername string

@description('Windows administrator password.')
@secure()
param windowsAdminPassword string

@description('Resource IDs of app-tier data disks (order matches appVmNames).')
param appDataDiskIds array

@description('Resource ID of the database data disk.')
param dbDataDiskId string

var linuxPublisher = 'Canonical'
var linuxOffer = '0001-com-ubuntu-server-jammy'
var linuxSku = '22_04-lts-gen2'
var winPublisher = 'MicrosoftWindowsServer'
var winOffer = 'WindowsServer'
var winSku = '2025-Datacenter'

resource appPips 'Microsoft.Network/publicIPAddresses@2023-09-01' = [
  for name in appVmNames: {
    name: '${name}-pip'
    location: location
    sku: {
      name: 'Standard'
      tier: 'Regional'
    }
    properties: {
      publicIPAllocationMethod: 'Static'
    }
  }
]

resource appNics 'Microsoft.Network/networkInterfaces@2023-09-01' = [
  for i in range(0, length(appVmNames)): {
    name: '${appVmNames[i]}-nic'
    location: location
    properties: {
      ipConfigurations: [
        {
          name: 'ipconfig1'
          properties: {
            privateIPAddress: appPrivateIps[i]
            privateIPAllocationMethod: 'Static'
            subnet: {
              id: appSubnetId
            }
            publicIPAddress: {
              id: appPips[i].id
            }
          }
        }
      ]
    }
  }
]

resource dbNic 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: '${vmDbName}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAddress: vmDbPrivateIp
          privateIPAllocationMethod: 'Static'
          subnet: {
            id: dbSubnetId
          }
        }
      }
    ]
  }
}

resource appVms 'Microsoft.Compute/virtualMachines@2023-03-01' = [
  for i in range(0, length(appVmNames)): {
    name: appVmNames[i]
    location: location
    dependsOn: [
      appNics
    ]
    properties: {
      hardwareProfile: {
        vmSize: vmAppSize
      }
      osProfile: {
        computerName: appVmNames[i]
        adminUsername: linuxAdminUsername
        linuxConfiguration: {
          disablePasswordAuthentication: true
          ssh: {
            publicKeys: [
              {
                path: '/home/${linuxAdminUsername}/.ssh/authorized_keys'
                keyData: sshPublicKey
              }
            ]
          }
        }
      }
      storageProfile: {
        imageReference: {
          publisher: linuxPublisher
          offer: linuxOffer
          sku: linuxSku
          version: 'latest'
        }
        osDisk: {
          name: '${appVmNames[i]}-os'
          createOption: 'FromImage'
          managedDisk: {
            storageAccountType: 'Premium_LRS'
          }
        }
        dataDisks: [
          {
            lun: 0
            createOption: 'Attach'
            managedDisk: {
              id: appDataDiskIds[i]
            }
          }
        ]
      }
      networkProfile: {
        networkInterfaces: [
          {
            id: appNics[i].id
            properties: {
              primary: true
            }
          }
        ]
      }
    }
  }
]

resource dbVm 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: vmDbName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmDbSize
    }
    osProfile: {
      computerName: vmDbName
      adminUsername: windowsAdminUsername
      adminPassword: windowsAdminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: winPublisher
        offer: winOffer
        sku: winSku
        version: 'latest'
      }
      osDisk: {
        name: '${vmDbName}-os'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
      dataDisks: [
        {
          lun: 0
          createOption: 'Attach'
          managedDisk: {
            id: dbDataDiskId
          }
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: dbNic.id
          properties: {
            primary: true
          }
        }
      ]
    }
  }
}

resource appNginx 'Microsoft.Compute/virtualMachines/extensions@2023-03-01' = [
  for i in range(0, length(appVmNames)): {
    name: 'CustomScript'
    parent: appVms[i]
    location: location
    properties: {
      publisher: 'Microsoft.Azure.Extensions'
      type: 'CustomScript'
      typeHandlerVersion: '2.1'
      autoUpgradeMinorVersion: true
      settings: {
        commandToExecute: 'sudo apt-get update && sudo apt-get install -y nginx'
      }
    }
  }
]

// Static private IPs are defined by parameters; NICs use the same values—no need to read runtime NIC state for outputs.
@description('Private IP addresses for all VMs in order: app VMs then db VM.')
output vmPrivateIps array = concat(appPrivateIps, [vmDbPrivateIp])

@description('Resource IDs of the application VMs.')
output appVmResourceIds array = [for i in range(0, length(appVmNames)): appVms[i].id]

@description('Resource ID of the database VM.')
output vmDbResourceId string = dbVm.id
