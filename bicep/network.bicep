// TEACHING NOTE: NSG is associated to the subnet (not the NIC) so every NIC in that subnet inherits the same policy—simpler ops and consistent segmentation.

@description('Azure region for network resources.')
param location string

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

@description('Resource group name used for resource tags (documentation).')
param resourceGroupName string

resource nsgApp 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: nsgAppName
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowHTTPInternet'
        properties: {
          priority: 100
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowHTTPSInternet'
        properties: {
          priority: 110
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowSSHInternet'
        properties: {
          priority: 120
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          priority: 4096
          access: 'Deny'
          direction: 'Inbound'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource nsgDb 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: nsgDbName
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowSQLFromAppSubnet'
        properties: {
          priority: 100
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '1433'
          sourceAddressPrefix: subnetAppPrefix
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          priority: 4096
          access: 'Deny'
          direction: 'Inbound'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vnetName
  location: location
  tags: {
    'lab-resource-group': resourceGroupName
  }
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: subnetAppName
        properties: {
          addressPrefix: subnetAppPrefix
          networkSecurityGroup: {
            id: nsgApp.id
          }
        }
      }
      {
        name: subnetDbName
        properties: {
          addressPrefix: subnetDbPrefix
          networkSecurityGroup: {
            id: nsgDb.id
          }
        }
      }
    ]
  }
}

@description('Resource ID of the virtual network.')
output vnetId string = vnet.id

@description('Resource ID of the application subnet.')
output appSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, subnetAppName)

@description('Resource ID of the database subnet.')
output dbSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, subnetDbName)
