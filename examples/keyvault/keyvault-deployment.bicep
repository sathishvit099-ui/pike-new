targetScope = 'resourceGroup'

// Standalone Key Vault deployment template for the Pike project.
// Re-running this deployment against the SAME subscription, resource group,
// and Key Vault name is idempotent: ARM/Bicep updates the same resource.

@description('Globally unique Key Vault name (3-24 characters; letters, numbers and hyphens).')
@minLength(3)
@maxLength(24)
param keyVaultName string

@description('Azure region, for example centralus.')
param location string = resourceGroup().location

@description('Microsoft Entra tenant ID for the subscription.')
param tenantId string

@description('Key Vault SKU.')
@allowed([
  'standard'
  'premium'
])
param skuName string = 'standard'

@description('Use Azure RBAC for Key Vault data-plane permissions.')
param enableRbacAuthorization bool = true

@description('Enable purge protection. Once enabled, it cannot be disabled.')
param enablePurgeProtection bool = true

@description('Soft-delete retention period in days.')
@minValue(7)
@maxValue(90)
param softDeleteRetentionInDays int = 90

@description('Public network access setting.')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Enabled'

@description('Resource tags.')
param tags object = {}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    tenantId: tenantId
    enableRbacAuthorization: enableRbacAuthorization
    enablePurgeProtection: enablePurgeProtection
    softDeleteRetentionInDays: softDeleteRetentionInDays
    publicNetworkAccess: publicNetworkAccess
    sku: {
      name: skuName
      family: 'A'
    }
  }
}

output keyVaultId string = keyVault.id
output keyVaultNameOut string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
