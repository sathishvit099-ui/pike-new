// Pike naming:
//   Azure SQL (apps) server: sql-<workload>-<env>   e.g. sql-app-kbase-dev
//   Database:                <purpose>             e.g. app

@description('Environment token.')
@allowed(['dev', 'qa', 'uat', 'prod'])
param environmentName string

@description('Workload token (used for the workload tag).')
@minLength(3)
@maxLength(60)
param workload string

@description('Deployment purpose token (input.json target.purpose); used as the database name.')
@minLength(2)
@maxLength(11)
param purpose string

@description('Azure region.')
param location string

@description('SQL administrator login.')
param administratorLogin string

@secure()
@description('SQL administrator password.')
param administratorLoginPassword string

@description('SQL Server version.')
param sqlServerVersion string

@description('Database SKU name.')
param databaseSkuName string

@description('Database SKU tier.')
param databaseSkuTier string

@description('Database SKU capacity.')
param databaseCapacity int

@description('Maximum database size in GB.')
@minValue(1)
param databaseMaxSizeGB int

@description('Public network access setting.')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string

@description('Minimum TLS version.')
param minimumTlsVersion string

@description('Tags. Must contain owner, cost-center and data-class; env and workload are added here.')
param tags object

var serverName = 'sql-${workload}-${environmentName}'
var resourceTags = union(tags, { env: environmentName, workload: workload })

resource sqlServer 'Microsoft.Sql/servers@2021-11-01' = {
  name: serverName
  location: location
  tags: resourceTags
  properties: {
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
    version: sqlServerVersion
    publicNetworkAccess: publicNetworkAccess
    minimalTlsVersion: minimumTlsVersion
  }
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2021-11-01' = {
  parent: sqlServer
  name: purpose
  location: location
  tags: resourceTags
  sku: {
    name: databaseSkuName
    tier: databaseSkuTier
    capacity: databaseCapacity
  }
  properties: {
    maxSizeBytes: databaseMaxSizeGB * 1073741824
  }
}

output deployedResourceId string = sqlServer.id
output deployedResourceName string = sqlServer.name
output sqlDatabaseId string = sqlDatabase.id
output sqlDatabaseName string = sqlDatabase.name
