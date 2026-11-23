// Pike naming: snet-<purpose> inside vnet-pike-<env>      e.g. snet-app
// Optional associations (same purpose): nsg-pike-<purpose>-<env>, rt-pike-<purpose>-<env>

@description('Environment token.')
@allowed(['dev', 'qa', 'uat', 'prod'])
param environmentName string

@description('Deployment purpose token (input.json target.purpose).')
@minLength(2)
@maxLength(11)
param purpose string

@description('Subnet CIDR prefix.')
param addressPrefix string

@description('Associate nsg-pike-<purpose>-<env> with this subnet.')
param attachNetworkSecurityGroup bool

@description('Associate rt-pike-<purpose>-<env> with this subnet.')
param attachRouteTable bool

@description('Subnet service endpoints configuration.')
param serviceEndpoints array

@description('Private endpoint network policy setting.')
@allowed([
  'Enabled'
  'Disabled'
  'NetworkSecurityGroupEnabled'
  'RouteTableEnabled'
])
param privateEndpointNetworkPolicies string

@description('Private link service network policy setting.')
@allowed([
  'Enabled'
  'Disabled'
])
param privateLinkServiceNetworkPolicies string

var vnetName = 'vnet-pike-${environmentName}'
var subnetName = 'snet-${purpose}'
var networkSecurityGroupName = 'nsg-pike-${purpose}-${environmentName}'
var routeTableName = 'rt-pike-${purpose}-${environmentName}'

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' existing = {
  name: vnetName
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' = {
  parent: vnet
  name: subnetName
  properties: {
    addressPrefix: addressPrefix
    serviceEndpoints: serviceEndpoints
    privateEndpointNetworkPolicies: privateEndpointNetworkPolicies
    privateLinkServiceNetworkPolicies: privateLinkServiceNetworkPolicies
    networkSecurityGroup: attachNetworkSecurityGroup ? {
      id: resourceId('Microsoft.Network/networkSecurityGroups', networkSecurityGroupName)
    } : null
    routeTable: attachRouteTable ? {
      id: resourceId('Microsoft.Network/routeTables', routeTableName)
    } : null
  }
}

output deployedResourceId string = subnet.id
output deployedResourceName string = subnet.name
