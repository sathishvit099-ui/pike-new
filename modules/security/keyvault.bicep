// Pike naming: kv-pike-<purpose>-<env>      e.g. kv-pike-app-dev
// Globally unique via the "pike" prefix. Length limit 24: kv-pike-(8) + purpose(<=11) + -(1) + env(<=4) = 24.

@description('Environment token.')
@allowed(['dev', 'qa', 'uat', 'prod'])
param environmentName string

@description('Workload token (used for the workload tag).')
@minLength(3)
@maxLength(60)
param workload string

@description('Deployment purpose token (input.json target.purpose), lowercase letters/digits.')
@minLength(2)
@maxLength(11)
param purpose string

@description('Azure region.')
param location string

@description('Microsoft Entra tenant ID. Defaults to the tenant of the deployment.')
param tenantId string = tenant().tenantId

@description('Key Vault SKU name.')
@allowed([
  'standard'
  'premium'
])
param skuName string

@description('Key Vault SKU family.')
@allowed([
  'A'
])
param skuFamily string

@description('Use Azure RBAC for data-plane authorization.')
param enableRbacAuthorization bool

@description('Enable purge protection.')
param enablePurgeProtection bool

@description('Soft-delete retention in days.')
@minValue(7)
@maxValue(90)
param softDeleteRetentionInDays int

@description('Public network access setting.')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string

@description('Tags. Must contain owner, cost-center and data-class; env and workload are added here.')
param tags object

var keyVaultName = 'kv-pike-${purpose}-${environmentName}'

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: union(tags, { env: environmentName, workload: workload })
  properties: {
    tenantId: tenantId
    enableRbacAuthorization: enableRbacAuthorization
    enablePurgeProtection: enablePurgeProtection
    softDeleteRetentionInDays: softDeleteRetentionInDays
    publicNetworkAccess: publicNetworkAccess
    sku: {
      name: skuName
      family: skuFamily
    }
  }
}

output deployedResourceId string = keyVault.id
output deployedResourceName string = keyVault.name
