// Pike naming: snet-<purpose>-agw inside vnet-pike-<env>      e.g. snet-app-agw
// (the -agw suffix keeps the gateway subnet distinct from the main snet-<purpose> subnet)

@description('Environment token.')
@allowed(['dev', 'qa', 'uat', 'prod'])
param environmentName string

@description('Deployment purpose token (input.json target.purpose).')
@minLength(2)
@maxLength(11)
param purpose string

@description('Subnet CIDR prefix.')
param subnetAddressPrefix string

var vnetName = 'vnet-pike-${environmentName}'
var subnetName = 'snet-${purpose}-agw'

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' existing = {
  name: vnetName
}

resource applicationGatewaySubnet 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' = {
  parent: vnet
  name: subnetName
  properties: {
    addressPrefix: subnetAddressPrefix
  }
}

output deployedResourceId string = applicationGatewaySubnet.id
output deployedResourceName string = applicationGatewaySubnet.name
