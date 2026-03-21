// TEACHING NOTE: VNet auto-registration creates DNS records for VM hostnames in the zone; manual A records give stable friendly names (app01, app02, db01) for apps and docs regardless of VM computer name.

@description('Resource ID of the virtual network to link (for Private DNS resolution).')
param vnetId string

@description('Short label used to name the VNet link resource (must be DNS-safe).')
param vnetLinkName string

@description('Private DNS zone name (e.g. internal.contoso.local).')
param privateDnsZoneName string

@description('IPv4 for app01.internal.contoso.local (first app VM).')
param app01PrivateIp string

@description('IPv4 for app02.internal.contoso.local (second app VM).')
param app02PrivateIp string

@description('IPv4 for db01.internal.contoso.local (database VM).')
param db01PrivateIp string

resource zone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateDnsZoneName
  location: 'global'
}

resource vnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: zone
  name: vnetLinkName
  location: 'global'
  properties: {
    registrationEnabled: true
    virtualNetwork: {
      id: vnetId
    }
  }
}

resource app01A 'Microsoft.Network/privateDnsZones/A@2020-06-01' = {
  parent: zone
  name: 'app01'
  dependsOn: [
    vnetLink
  ]
  properties: {
    ttl: 3600
    aRecords: [
      {
        ipv4Address: app01PrivateIp
      }
    ]
  }
}

resource app02A 'Microsoft.Network/privateDnsZones/A@2020-06-01' = {
  parent: zone
  name: 'app02'
  dependsOn: [
    vnetLink
  ]
  properties: {
    ttl: 3600
    aRecords: [
      {
        ipv4Address: app02PrivateIp
      }
    ]
  }
}

resource db01A 'Microsoft.Network/privateDnsZones/A@2020-06-01' = {
  parent: zone
  name: 'db01'
  dependsOn: [
    vnetLink
  ]
  properties: {
    ttl: 3600
    aRecords: [
      {
        ipv4Address: db01PrivateIp
      }
    ]
  }
}

@description('Resource ID of the private DNS zone.')
output privateDnsZoneId string = zone.id
