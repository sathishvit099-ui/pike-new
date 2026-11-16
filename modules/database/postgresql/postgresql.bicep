@description('PostgreSQL Flexible Server name. Must be globally unique in Azure.')
param serverName string

@description('Azure region. Must match the VNet region for VNet-integrated private access.')
param location string

@description('PostgreSQL administrator login name.')
param administratorLogin string

@secure()
@description('PostgreSQL administrator password. Supply through the POSTGRES_ADMIN_PASSWORD GitHub secret.')
param administratorLoginPassword string

@description('PostgreSQL major version.')
@allowed([
  '14'
  '15'
  '16'
])
param version string = '16'

@description('Compute SKU name.')
param skuName string = 'Standard_B1ms'

@description('Compute tier.')
@allowed([
  'Burstable'
  'GeneralPurpose'
  'MemoryOptimized'
])
param skuTier string = 'Burstable'

@description('PostgreSQL storage size in GB. Minimum supported size is 32 GB.')
@minValue(32)
param storageSizeGB int = 32

@description('Backup retention in days.')
@minValue(7)
@maxValue(35)
param backupRetentionDays int = 7

@description('Existing VNet name. The VNet must be in the same resource group as this deployment.')
param vnetName string

@description('Dedicated subnet name for PostgreSQL Flexible Server.')
param subnetName string

@description('Non-overlapping CIDR range for the dedicated PostgreSQL subnet.')
param subnetAddressPrefix string

@description('Private DNS zone name. Must end with .postgres.database.azure.com.')
param privateDnsZoneName string = 'private.postgres.database.azure.com'

@description('Name of the virtual network link for the PostgreSQL private DNS zone.')
param privateDnsZoneLinkName string

@description('Resource tags.')
param tags object

resource existingVnet 'Microsoft.Network/virtualNetworks@2023-09-01' existing = {
  name: vnetName
}

resource postgresqlSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' = {
  parent: existingVnet
  name: subnetName
  properties: {
    addressPrefix: subnetAddressPrefix
    delegations: [
      {
        name: 'postgresql-flexible-server-delegation'
        properties: {
          serviceName: 'Microsoft.DBforPostgreSQL/flexibleServers'
        }
      }
    ]
  }
}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateDnsZoneName
  location: 'global'
}

resource privateDnsVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZone
  name: privateDnsZoneLinkName
  location: 'global'
  properties: {
    virtualNetwork: {
      id: existingVnet.id
    }
    registrationEnabled: false
  }
}

resource postgresqlServer 'Microsoft.DBforPostgreSQL/flexibleServers@2024-08-01' = {
  name: serverName
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: skuTier
  }
  properties: {
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
    version: version
    authConfig: {
      activeDirectoryAuth: 'Disabled'
      passwordAuth: 'Enabled'
    }
    backup: {
      backupRetentionDays: backupRetentionDays
      geoRedundantBackup: 'Disabled'
    }
    highAvailability: {
      mode: 'Disabled'
    }
    network: {
      delegatedSubnetResourceId: postgresqlSubnet.id
      privateDnsZoneArmResourceId: privateDnsZone.id
      publicNetworkAccess: 'Disabled'
    }
    storage: {
      storageSizeGB: storageSizeGB
      autoGrow: 'Disabled'
      type: 'Premium_LRS'
    }
  }
  dependsOn: [
    privateDnsVnetLink
  ]
}

output serverId string = postgresqlServer.id
output serverNameOut string = postgresqlServer.name
output fullyQualifiedDomainName string = postgresqlServer.properties.fullyQualifiedDomainName
output delegatedSubnetId string = postgresqlSubnet.id
output privateDnsZoneId string = privateDnsZone.id
