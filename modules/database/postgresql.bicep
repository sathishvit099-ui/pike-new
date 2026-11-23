// Pike naming:
//   Server:            psql-pike-<purpose>-<env>      e.g. psql-pike-mdm-dev
//   Delegated subnet:  snet-<purpose>-psql inside vnet-pike-<env>
//   Private DNS link:  link-vnet-pike-<env>
// Globally unique via the "pike" prefix.

@description('Environment token.')
@allowed(['dev', 'qa', 'uat', 'prod'])
param environmentName string

@description('Deployment purpose token (input.json target.purpose).')
@minLength(2)
@maxLength(11)
param purpose string

@description('Workload token (used for the workload tag).')
@minLength(3)
@maxLength(60)
param workload string

@description('Azure region. Must match the VNet region for VNet-integrated private access.')
param location string

@description('PostgreSQL administrator login name.')
param administratorLogin string

@secure()
@description('PostgreSQL administrator password.')
param administratorLoginPassword string

@description('PostgreSQL major version.')
@allowed([
  '14'
  '15'
  '16'
])
param version string

@description('Compute SKU name.')
param skuName string

@description('Compute tier.')
@allowed([
  'Burstable'
  'GeneralPurpose'
  'MemoryOptimized'
])
param skuTier string

@description('PostgreSQL storage size in GB.')
@minValue(32)
param storageSizeGB int

@description('Backup retention in days.')
@minValue(7)
@maxValue(35)
param backupRetentionDays int

@description('Geo-redundant backup.')
@allowed([
  'Enabled'
  'Disabled'
])
param geoRedundantBackup string

@description('High availability mode.')
@allowed([
  'Disabled'
  'SameZone'
  'ZoneRedundant'
])
param highAvailabilityMode string

@description('Dedicated subnet CIDR.')
param subnetAddressPrefix string

@description('Private DNS zone name, normally privatelink.postgres.database.azure.com.')
param privateDnsZoneName string

@description('Tags. Must contain owner, cost-center and data-class; env and workload are added here.')
param tags object

var serverName = 'psql-pike-${purpose}-${environmentName}'
var vnetName = 'vnet-pike-${environmentName}'
var subnetName = 'snet-${purpose}-psql'
var privateDnsZoneLinkName = 'link-${vnetName}'

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

resource postgresqlServer 'Microsoft.DBforPostgreSQL/flexibleServers@2023-06-01-preview' = {
  name: serverName
  location: 'centralus'
  tags: union(tags, { env: environmentName, workload: workload })
  sku: {
    name: skuName
    tier: skuTier
  }
  properties: {
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
    version: version
    backup: {
      backupRetentionDays: backupRetentionDays
      geoRedundantBackup: geoRedundantBackup
    }
    highAvailability: {
      mode: highAvailabilityMode
    }
    network: {
      delegatedSubnetResourceId: postgresqlSubnet.id
      privateDnsZoneArmResourceId: privateDnsZone.id
    }
    storage: {
      storageSizeGB: storageSizeGB
    }
  }
  dependsOn: [
    privateDnsVnetLink
  ]
}

output deployedResourceId string = postgresqlServer.id
output deployedResourceName string = postgresqlServer.name
output fullyQualifiedDomainName string = postgresqlServer.properties.fullyQualifiedDomainName
output delegatedSubnetId string = postgresqlSubnet.id
output privateDnsZoneId string = privateDnsZone.id
