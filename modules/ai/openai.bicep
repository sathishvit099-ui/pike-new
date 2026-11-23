// Pike naming: oai-pike-<purpose>-<env>      e.g. oai-pike-assist-dev
// The custom subdomain (globally unique) uses the same value; uniqueness via "pike".

@description('Environment token.')
@allowed(['dev', 'qa', 'uat', 'prod'])
param environmentName string

@description('Workload token (used for the workload tag).')
@minLength(3)
@maxLength(60)
param workload string

@description('Deployment purpose token (input.json target.purpose).')
@minLength(2)
@maxLength(11)
param purpose string

@description('Azure region.')
param location string

@description('Azure OpenAI SKU name.')
param skuName string

@description('Public network access setting.')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string

@description('Tags. Must contain owner, cost-center and data-class; env and workload are added here.')
param tags object

var accountName = 'oai-pike-${purpose}-${environmentName}'

resource openAiService 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: accountName
  location: location
  kind: 'OpenAI'
  sku: {
    name: skuName
  }
  properties: {
    customSubDomainName: accountName
    publicNetworkAccess: publicNetworkAccess
  }
  tags: union(tags, { env: environmentName, workload: workload })
}

output deployedResourceId string = openAiService.id
output deployedResourceName string = openAiService.name
output endpoint string = openAiService.properties.endpoint
