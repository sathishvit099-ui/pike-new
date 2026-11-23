// Pike naming: rt-pike-<purpose>-<env>      e.g. rt-pike-private-dev

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

@description('Disable BGP route propagation.')
param disableBgpRoutePropagation bool

@description('Route objects matching Azure route properties.')
param routes array

@description('Tags. Must contain owner, cost-center and data-class; env and workload are added here.')
param tags object

var routeTableName = 'rt-pike-${purpose}-${environmentName}'

resource routeTable 'Microsoft.Network/routeTables@2023-09-01' = {
  name: routeTableName
  location: location
  tags: union(tags, { env: environmentName, workload: workload })
  properties: {
    disableBgpRoutePropagation: disableBgpRoutePropagation
    routes: [
      for route in routes: {
        name: route.name
        properties: {
          addressPrefix: route.addressPrefix
          nextHopType: route.nextHopType
          nextHopIpAddress: contains(route, 'nextHopIpAddress') ? route.nextHopIpAddress : null
        }
      }
    ]
  }
}

output deployedResourceId string = routeTable.id
output deployedResourceName string = routeTable.name
