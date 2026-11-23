// Pike naming: vnet-pike-<env>      e.g. vnet-pike-dev
// The workflow skips this template when the VNet already exists, because re-applying it
// would remove subnets that were added by the subnet modules.

@description('Environment token.')
@allowed(['dev', 'qa', 'uat', 'prod'])
param environmentName string

@description('Workload token (used for the workload tag).')
@minLength(3)
@maxLength(60)
param workload string

@description('Azure region.')
param location string

@description('Virtual network CIDR prefixes, for example ["10.40.0.0/16"].')
param addressPrefixes array

@description('Custom DNS server IP addresses; empty array for Azure-provided DNS.')
param dnsServers array

@description('Tags. Must contain owner, cost-center and data-class; env and workload are added here.')
param tags object

var vnetName = 'vnet-pike-${environmentName}'

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vnetName
  location: location
  tags: union(tags, { env: environmentName, workload: workload })
  properties: {
    addressSpace: {
      addressPrefixes: addressPrefixes
    }
    dhcpOptions: !empty(dnsServers) ? {
      dnsServers: dnsServers
    } : null
    subnets: []
  }
}

output deployedResourceId string = vnet.id
output deployedResourceName string = vnet.name
