targetScope = 'subscription'

// Pike naming convention: rg-<workload>-<env>      e.g. rg-int-sap-orders-dev
// <workload> = int-<system>-<entity> | app-<name> | platform-svc | shared-infra
// Required tags: env, workload, owner, cost-center, data-class.

@description('Environment token.')
@allowed(['dev', 'qa', 'uat', 'prod'])
param environmentName string

@description('Workload token: int-<system>-<entity>, app-<name>, platform-svc or shared-infra.')
@minLength(3)
@maxLength(60)
param workload string

@description('Azure region.')
param location string

@description('Tags. Must contain owner, cost-center and data-class; env and workload are added here.')
param tags object

var resourceGroupName = 'rg-${workload}-${environmentName}'

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
  tags: union(tags, { env: environmentName, workload: workload })
}

output deployedResourceId string = rg.id
output deployedResourceName string = rg.name
