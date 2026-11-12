@description('Azure OpenAI account name.')
param accountName string

@description('Unique deployment suffix from GitHub Actions run ID and attempt.')
param deploymentSuffix string

@description('Azure region.')
param location string

@description('Azure OpenAI SKU name.')
param skuName string

@description('Custom subdomain name for the Azure OpenAI endpoint.')
param customSubDomainName string

@description('Public network access setting.')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string

@description('Resource tags.')
param tags object

var uniqueAccountName = '${substring(accountName, 0, min(length(accountName), 20))}${uniqueString(subscription().id, resourceGroup().id, deploymentSuffix)}'

resource openAiService 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: uniqueAccountName
  location: location
  kind: 'OpenAI'
  sku: {
    name: skuName
  }
  properties: {
    customSubDomainName: uniqueAccountName
    publicNetworkAccess: publicNetworkAccess
  }
  tags: tags
}

output accountId string = openAiService.id
output accountName string = openAiService.name
output location string = openAiService.location
