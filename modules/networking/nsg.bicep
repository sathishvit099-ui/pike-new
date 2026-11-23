// Pike naming: nsg-pike-<purpose>-<env>      e.g. nsg-pike-app-dev

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

@description('Security rule objects matching Azure NSG security rule properties.')
param securityRules array

@description('Tags. Must contain owner, cost-center and data-class; env and workload are added here.')
param tags object

var nsgName = 'nsg-pike-${purpose}-${environmentName}'

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: nsgName
  location: location
  tags: union(tags, { env: environmentName, workload: workload })
  properties: {
    securityRules: [
      for rule in securityRules: {
        name: rule.name
        properties: {
          description: contains(rule, 'description') ? rule.description : null
          protocol: rule.protocol
          sourcePortRange: rule.sourcePortRange
          destinationPortRange: rule.destinationPortRange
          sourceAddressPrefix: rule.sourceAddressPrefix
          destinationAddressPrefix: rule.destinationAddressPrefix
          access: rule.access
          priority: rule.priority
          direction: rule.direction
        }
      }
    ]
  }
}

output deployedResourceId string = nsg.id
output deployedResourceName string = nsg.name
