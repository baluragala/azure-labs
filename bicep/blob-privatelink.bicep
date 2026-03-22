// TEACHING NOTE: Private Link exposes the storage account’s blob sub-resource on a private IP inside your VNet. Traffic to the blob FQDN stays on Microsoft’s backbone instead of the public internet. The zone `privatelink.blob.core.windows.net` is the standard Private DNS zone so `*.blob.core.windows.net` resolves to that private IP from linked VNets.

@description('Azure region for the storage account and private endpoint.')
param location string

@description('Resource ID of the subnet used only for private endpoints (no delegation).')
param privateEndpointSubnetId string

@description('Resource ID of the virtual network (Private DNS zone link target).')
param vnetId string

@description('Name of the private endpoint resource.')
param privateEndpointName string

@description('Name of the VNet link resource under the blob Private DNS zone.')
param blobPrivateDnsVnetLinkName string

// Globally unique name: lowercase alphanumeric, 3–24 chars.
var storageAccountName = take(toLower('st${uniqueString(resourceGroup().id, 'blobpl')}'), 24)

var blobPrivateDnsZoneName = 'privatelink.blob.${environment().suffixes.storage}'

resource stg 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    publicNetworkAccess: 'Disabled'
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }
  }
}

resource blobSvc 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  name: 'default'
  parent: stg
}

resource labContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: 'lab-data'
  parent: blobSvc
  properties: {
    publicAccess: 'None'
  }
}

resource blobPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: blobPrivateDnsZoneName
  location: 'global'
}

resource blobDnsVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: blobPrivateDnsZone
  name: blobPrivateDnsVnetLinkName
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

resource pe 'Microsoft.Network/privateEndpoints@2023-09-01' = {
  name: privateEndpointName
  location: location
  dependsOn: [
    blobDnsVnetLink
  ]
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'blob-pls-conn'
        properties: {
          privateLinkServiceId: stg.id
          groupIds: [
            'blob'
          ]
        }
      }
    ]
  }
}

resource peDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-09-01' = {
  name: 'default'
  parent: pe
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-blob'
        properties: {
          privateDnsZoneId: blobPrivateDnsZone.id
        }
      }
    ]
  }
}

@description('Globally unique storage account name (blob endpoint host prefix).')
output storageAccountName string = stg.name

@description('Blob service URL (same hostname clients use; resolves privately inside linked VNets).')
output blobEndpointUri string = 'https://${stg.name}.blob.${environment().suffixes.storage}/'

@description('Resource ID of the private endpoint.')
output privateEndpointId string = pe.id

@description('Resource ID of the Private DNS zone for blob Private Link.')
output blobPrivateDnsZoneId string = blobPrivateDnsZone.id
